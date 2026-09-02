require "test_helper"

class Api::V1::ImportsTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:main_app)
    @common = namespaces(:main_app_common)
    @en = locales(:main_app_en)
    @url = "/api/v1/projects/#{@project.slug}/import"
    @en.mark_as_source!
    # A translator's PAT carries the save_missing scope and names the author.
    @raw = PersonalAccessToken.issue(user: users(:translator), name: "test")
    @auth = { "Authorization" => "Bearer #{@raw}" }
  end

  def post_import(headers: @auth, **body)
    post @url, params: body, headers: headers, as: :json
  end

  test "writes source-locale values as draft translations authored by the token user" do
    assert_difference [ -> { TranslationKey.count }, -> { Translation.count } ], 1 do
      post_import(locale: "en", session: "feat/x", namespaces: { "common" => { "welcome" => "Hi" } })
    end
    assert_response :success
    assert_equal 1, response.parsed_body["written"]

    key = @common.translation_keys.find_by(key: "welcome")
    translation = key.translations.find_by(locale: @en)
    assert_equal "Hi", translation.value
    assert_equal users(:translator), translation.author
    assert_equal "feat/x", translation.session
    assert translation.draft?, "pushed values land as unpublished drafts"
  end

  test "materializes the session's playground JSON in storage and returns its path" do
    post_import(locale: "en", session: "feat/x", namespaces: { "common" => { "welcome" => "Hi" } })
    assert_response :success

    paths = response.parsed_body["preview_paths"]
    assert_equal 1, paths.size
    assert_includes paths.first, "sessions/feat/x/"

    json = JSON.parse(ActiveStorage::Blob.service.download(paths.first))
    assert_equal "Hi", json["welcome"]
  end

  test "a sessionless push materializes no preview" do
    post_import(locale: "en", namespaces: { "common" => { "welcome" => "Hi" } })
    assert_response :success
    assert_equal [], response.parsed_body["preview_paths"]
  end

  test "every push materializes the playground (published + all drafts)" do
    post_import(locale: "en", namespaces: { "common" => { "welcome" => "Hi" } })
    assert_response :success

    paths = response.parsed_body["playground_paths"]
    assert_equal 1, paths.size
    assert_includes paths.first, "playground/"

    json = JSON.parse(ActiveStorage::Blob.service.download(paths.first))
    assert_equal "Hi", json["welcome"]
  end

  test "flattens nested keys into dotted keys" do
    post_import(locale: "en", namespaces: { "common" => { "home" => { "title" => "Welcome" } } })
    assert_response :success
    assert @common.translation_keys.exists?(key: "home.title")
  end

  test "creates a brand-new namespace when pushed" do
    assert_difference -> { @project.namespaces.count }, 1 do
      post_import(locale: "en", namespaces: { "emails" => { "subject" => "Hello" } })
    end
    assert_response :success
  end

  test "a re-push updates the same draft instead of duplicating" do
    post_import(locale: "en", namespaces: { "common" => { "welcome" => "Hi" } })
    assert_no_difference -> { Translation.count } do
      post_import(locale: "en", namespaces: { "common" => { "welcome" => "Hello" } })
    end
    assert_equal "Hello", @common.translation_keys.find_by(key: "welcome").translations.sole.value
  end

  test "editing an already-published key returns it to draft" do
    translations(:greeting_en).publish(by: users(:admin))
    post_import(locale: "en", namespaces: { "common" => { "greeting" => "Hey" } })
    assert_response :success

    greeting = translations(:greeting_en).reload
    assert_equal "Hey", greeting.value
    assert greeting.draft?, "a push edit unpublishes the live value, like an editor edit"
  end

  test "skips blank leaf values" do
    post_import(locale: "en", namespaces: { "common" => { "a" => "", "b" => "x" } })
    assert_response :success
    assert_equal 1, response.parsed_body["written"]
    assert_not @common.translation_keys.exists?(key: "a")
    assert @common.translation_keys.exists?(key: "b")
  end

  test "writes non-source locale values as drafts too" do
    post_import(locale: "pt-BR", session: "feat/x", namespaces: { "common" => { "welcome" => "Oi" } })
    assert_response :success

    translation = @common.translation_keys.find_by(key: "welcome")
      .translations.find_by(locale: locales(:main_app_pt_br))
    assert_equal "Oi", translation.value
    assert translation.draft?, "non-source pushes stay unpublished until reviewed"
  end

  test "404 for an unknown locale" do
    post_import(locale: "zz", namespaces: { "common" => { "welcome" => "Hi" } })
    assert_response :not_found
  end

  test "422 when locale is missing" do
    post_import(namespaces: { "common" => { "welcome" => "Hi" } })
    assert_response :unprocessable_entity
  end

  test "422 when namespaces is empty" do
    post_import(locale: "en", namespaces: {})
    assert_response :unprocessable_entity
  end

  test "forbidden for a read-only token" do
    raw = PersonalAccessToken.issue(user: users(:viewer), name: "test")
    post_import(headers: { "Authorization" => "Bearer #{raw}" },
                locale: "en", namespaces: { "common" => { "welcome" => "Hi" } })
    assert_response :forbidden
  end

  test "a per-project token authors drafts as its creator" do
    post_import(headers: { "Authorization" => "Bearer test-save-missing-token" },
                locale: "en", namespaces: { "common" => { "welcome" => "Hi" } })
    assert_response :success
    assert_equal users(:admin), @common.translation_keys.find_by(key: "welcome").translations.sole.author
  end

  test "401 when the bearer token is invalid" do
    post_import(headers: { "Authorization" => "Bearer nope" },
                locale: "en", namespaces: { "common" => { "welcome" => "Hi" } })
    assert_response :unauthorized
  end
end
