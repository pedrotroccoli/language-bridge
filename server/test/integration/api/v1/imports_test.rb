require "test_helper"

class Api::V1::ImportsTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:main_app)
    @url = "/api/v1/projects/#{@project.slug}/import"
    locales(:main_app_en).mark_as_source!
    # A translator's PAT carries the save_missing scope and names the proposer.
    @raw = PersonalAccessToken.regenerate_for(users(:translator))
    @auth = { "Authorization" => "Bearer #{@raw}" }
  end

  def post_import(headers: @auth, **body)
    post @url, params: body, headers: headers, as: :json
  end

  test "stages source-locale values as pending proposals authored by the token user" do
    assert_difference -> { Translation::Proposal.count }, 1 do
      post_import(locale: "en", namespaces: { "common" => { "welcome" => "Hi" } })
    end
    assert_response :success
    assert_equal 1, response.parsed_body["proposed"]

    proposal = Translation::Proposal.last
    assert_equal "welcome", proposal.key
    assert_equal "Hi", proposal.value
    assert_equal namespaces(:main_app_common), proposal.namespace
    assert_equal users(:translator), proposal.author
  end

  test "flattens nested keys into dotted proposals" do
    post_import(locale: "en", namespaces: { "common" => { "home" => { "title" => "Welcome" } } })
    assert_response :success
    assert_equal "home.title", Translation::Proposal.last.key
  end

  test "creates a brand-new namespace when proposed" do
    assert_difference -> { @project.namespaces.count }, 1 do
      post_import(locale: "en", namespaces: { "emails" => { "subject" => "Hello" } })
    end
    assert_response :success
    assert @project.namespaces.exists?(name: "emails")
  end

  test "a re-push overwrites the pending proposal instead of duplicating" do
    post_import(locale: "en", namespaces: { "common" => { "welcome" => "Hi" } })
    assert_no_difference -> { Translation::Proposal.count } do
      post_import(locale: "en", namespaces: { "common" => { "welcome" => "Hello" } })
    end
    assert_equal "Hello", Translation::Proposal.last.value
  end

  test "keeps proposals from different sessions separate for the same key" do
    post_import(locale: "en", session: "branch-a", namespaces: { "common" => { "welcome" => "Hi" } })
    post_import(locale: "en", session: "branch-b", namespaces: { "common" => { "welcome" => "Yo" } })
    assert_response :success
    assert_equal 2, Translation::Proposal.where(key: "welcome").count
    assert_equal "branch-b", response.parsed_body["session"]
  end

  test "skips blank leaf values" do
    post_import(locale: "en", namespaces: { "common" => { "a" => "", "b" => "x" } })
    assert_response :success
    assert_equal 1, response.parsed_body["proposed"]
    assert_equal "b", Translation::Proposal.last.key
  end

  test "does not touch the live key list until accepted" do
    assert_no_difference -> { TranslationKey.count } do
      post_import(locale: "en", namespaces: { "common" => { "brand.new" => "x" } })
    end
  end

  test "rejects a non-source locale" do
    post_import(locale: "pt-BR", namespaces: { "common" => { "welcome" => "Oi" } })
    assert_response :unprocessable_entity
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
    raw = PersonalAccessToken.regenerate_for(users(:viewer))
    post_import(headers: { "Authorization" => "Bearer #{raw}" },
                locale: "en", namespaces: { "common" => { "welcome" => "Hi" } })
    assert_response :forbidden
  end

  test "a per-project token authors proposals as its creator" do
    post_import(headers: { "Authorization" => "Bearer test-save-missing-token" },
                locale: "en", namespaces: { "common" => { "welcome" => "Hi" } })
    assert_response :success
    assert_equal users(:admin), Translation::Proposal.last.author
  end

  test "401 when the bearer token is invalid" do
    post_import(headers: { "Authorization" => "Bearer nope" },
                locale: "en", namespaces: { "common" => { "welcome" => "Hi" } })
    assert_response :unauthorized
  end
end
