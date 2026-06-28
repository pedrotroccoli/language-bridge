require "test_helper"

class NamespacesControllerTest < ActionDispatch::IntegrationTest
  test "show renders translation grid with key rows and locale columns" do
    sign_in_as(users(:translator))
    project = projects(:main_app)
    namespace = namespaces(:main_app_common)

    get project_namespace_path(project, namespace)
    assert_response :success
    assert_select ".translation-row", count: namespace.translation_keys.count
    assert_select ".translation-grid thead th", count: project.locales.count + 1
  end

  test "show hides admin structure actions for translator" do
    sign_in_as(users(:translator))
    get project_namespace_path(projects(:main_app), namespaces(:main_app_common))
    assert_select "button", text: /New key/, count: 0
    assert_select ".icon-btn--danger", count: 0
  end

  test "show lets translator edit values but viewer is read-only" do
    sign_in_as(users(:translator))
    get project_namespace_path(projects(:main_app), namespaces(:main_app_common))
    assert_select "textarea[aria-label]"

    sign_in_as(users(:viewer))
    get project_namespace_path(projects(:main_app), namespaces(:main_app_common))
    assert_select "textarea[aria-label]", count: 0
    assert_select ".translation-cell__value"
  end

  test "show prompts to add locale when none exist" do
    sign_in_as(users(:admin))
    project = Project.create!(name: "No Locales")
    namespace = project.namespaces.create!(name: "common")

    get project_namespace_path(project, namespace)
    assert_response :success
    assert_select ".empty-state", text: /No locales yet/
  end

  test "publish all button is disabled when there are no drafts" do
    sign_in_as(users(:admin))
    project = Project.create!(name: "NoDrafts")
    en = project.locales.create!(code: "en")
    namespace = project.namespaces.create!(name: "common")
    key = namespace.translation_keys.create!(project: project, key: "k")
    Translation::Publication.create!(translation: Translation.create!(translation_key: key, locale: en, value: "v"))

    get project_namespace_path(project, namespace)
    assert_select "#publish_all button[disabled]"
  end

  test "publish all button is enabled and counts drafts" do
    sign_in_as(users(:admin))
    project = Project.create!(name: "HasDrafts")
    en = project.locales.create!(code: "en")
    namespace = project.namespaces.create!(name: "common")
    key = namespace.translation_keys.create!(project: project, key: "k")
    Translation.create!(translation_key: key, locale: en, value: "v")

    get project_namespace_path(project, namespace)
    assert_select "#publish_all button:not([disabled])"
    assert_select "#publish_all button", text: /Publish all \(1\)/
  end

  test "translator publish_all publishes drafts with values and skips blanks" do
    sign_in_as(users(:translator))
    project = projects(:main_app)
    namespace = namespaces(:main_app_common)

    assert_difference "Translation::Publication.count", 2 do
      post publish_all_project_namespace_path(project, namespace)
    end
    assert_redirected_to project_namespace_path(project, namespace)
    assert_match(/Published 2/, flash[:notice])
    assert_nil translations(:farewell_en_missing).reload.publication
  end

  test "publish_all is idempotent and reports nothing to publish" do
    sign_in_as(users(:translator))
    project = projects(:main_app)
    namespace = namespaces(:main_app_common)
    post publish_all_project_namespace_path(project, namespace)

    assert_no_difference "Translation::Publication.count" do
      post publish_all_project_namespace_path(project, namespace)
    end
    assert_match(/Nothing to publish/, flash[:notice])
  end

  test "viewer cannot publish_all" do
    sign_in_as(users(:viewer))
    post publish_all_project_namespace_path(projects(:main_app), namespaces(:main_app_common))
    assert_response :forbidden
  end

  test "show limits to first 100 keys and reports total" do
    sign_in_as(users(:admin))
    project = Project.create!(name: "Big Project")
    project.locales.create!(code: "en")
    namespace = project.namespaces.create!(name: "common")
    105.times { |i| namespace.translation_keys.create!(project: project, key: format("k%03d", i)) }

    get project_namespace_path(project, namespace)
    assert_response :success
    assert_select ".translation-row", count: 100
    assert_select ".key-meta", text: /105 keys.*showing first 100/
    assert_select "input[type=search][name=q]"
  end

  test "show filters keys by query" do
    sign_in_as(users(:admin))
    project = Project.create!(name: "Searchy")
    project.locales.create!(code: "en")
    namespace = project.namespaces.create!(name: "common")
    namespace.translation_keys.create!(project: project, key: "home.title")
    namespace.translation_keys.create!(project: project, key: "home.cta")
    namespace.translation_keys.create!(project: project, key: "footer.copyright")

    get project_namespace_path(project, namespace), params: { q: "home" }
    assert_select ".translation-row", count: 2
    assert_select ".key-meta", text: /2 keys match/
  end

  test "show search matches translation values too" do
    sign_in_as(users(:admin))
    project = Project.create!(name: "ValueSearch")
    en = project.locales.create!(code: "en")
    namespace = project.namespaces.create!(name: "common")
    key = namespace.translation_keys.create!(project: project, key: "totally.unrelated")
    Translation.create!(translation_key: key, locale: en, value: "needle in here")
    namespace.translation_keys.create!(project: project, key: "other")

    get project_namespace_path(project, namespace), params: { q: "needle" }
    assert_select ".translation-row", count: 1
    assert_select ".translation-row code", text: "totally.unrelated"
  end

  test "show search ranks key matches before value-only matches" do
    sign_in_as(users(:admin))
    project = Project.create!(name: "RankSearch")
    en = project.locales.create!(code: "en")
    namespace = project.namespaces.create!(name: "common")
    value_match = namespace.translation_keys.create!(project: project, key: "aaa.first")
    Translation.create!(translation_key: value_match, locale: en, value: "match-token here")
    key_match = namespace.translation_keys.create!(project: project, key: "zzz.match-token")

    get project_namespace_path(project, namespace), params: { q: "match-token" }
    rows = css_select(".translation-row code").map(&:text)
    assert_equal [ "zzz.match-token", "aaa.first" ], rows
  end

  test "show shows no-match state for query with no results" do
    sign_in_as(users(:admin))
    get project_namespace_path(projects(:main_app), namespaces(:main_app_common)), params: { q: "zzzznope" }
    assert_response :success
    assert_select ".translation-row", count: 0
    assert_select ".empty-state", text: /No keys match/
  end

  test "admin imports nested json into a locale" do
    sign_in_as(users(:admin))
    project = projects(:main_app)
    namespace = namespaces(:main_app_common)
    en = locales(:main_app_en)
    greeting = translations(:greeting_en) # "Hello"

    assert_difference -> { namespace.translation_keys.count }, 3 do
      post import_project_namespace_path(project, namespace),
           params: { locale_id: en.id, file: fixture_file_upload("sample_import.json", "application/json") }
    end
    assert_redirected_to project_namespace_path(project, namespace)
    assert_match(/Imported 4 translations into en \(3 new keys\)/, flash[:notice])

    assert_equal "Hi from import", greeting.reload.value
    assert_equal "Hello", greeting.versions.order(:created_at).last.value
    assert_equal "Welcome", namespace.translation_keys.find_by(key: "home.title").translations.find_by(locale: en).value
    assert_equal "3", namespace.translation_keys.find_by(key: "count").translations.find_by(locale: en).value
  end

  test "translator cannot import" do
    sign_in_as(users(:translator))
    post import_project_namespace_path(projects(:main_app), namespaces(:main_app_common)),
         params: { locale_id: locales(:main_app_en).id, file: fixture_file_upload("sample_import.json", "application/json") }
    assert_response :forbidden
  end

  test "import without locale shows alert" do
    sign_in_as(users(:admin))
    post import_project_namespace_path(projects(:main_app), namespaces(:main_app_common)),
         params: { file: fixture_file_upload("sample_import.json", "application/json") }
    assert_match(/Select a locale/, flash[:alert])
  end

  test "import shows admin button only" do
    sign_in_as(users(:admin))
    get project_namespace_path(projects(:main_app), namespaces(:main_app_common))
    assert_select "button", text: /Import JSON/

    sign_in_as(users(:translator))
    get project_namespace_path(projects(:main_app), namespaces(:main_app_common))
    assert_select "button", text: /Import JSON/, count: 0
  end

  test "non-admin cannot create/update/destroy" do
    sign_in_as(users(:translator))
    project = projects(:main_app)
    namespace = namespaces(:main_app_common)

    assert_no_difference "Namespace.count" do
      post project_namespaces_path(project), params: { namespace: { name: "sneaky" } }
    end
    assert_response :forbidden

    patch project_namespace_path(project, namespace), params: { namespace: { name: "hijacked" } }
    assert_response :forbidden
    assert_equal "common", namespace.reload.name

    assert_no_difference "Namespace.count" do
      delete project_namespace_path(project, namespace)
    end
    assert_response :forbidden
  end

  test "admin creates namespace" do
    sign_in_as(users(:admin))
    project = projects(:main_app)

    assert_difference "project.namespaces.count", 1 do
      post project_namespaces_path(project), params: { namespace: { name: "checkout" } }
    end

    assert_redirected_to project_path(project)
    assert_match(/Namespace created/, flash[:notice])
    assert project.namespaces.exists?(name: "checkout")
  end

  test "admin sees alert and pre-filled form when creating with blank name" do
    sign_in_as(users(:admin))
    project = projects(:main_app)

    assert_no_difference "Namespace.count" do
      post project_namespaces_path(project), params: { namespace: { name: "" } }
    end
    assert_redirected_to project_path(project)
    assert_match(/blank/i, flash[:alert])
  end

  test "admin sees alert when creating with invalid format" do
    sign_in_as(users(:admin))
    project = projects(:main_app)

    assert_no_difference "Namespace.count" do
      post project_namespaces_path(project), params: { namespace: { name: "Has Space" } }
    end
    assert_redirected_to project_path(project)
    assert flash[:alert].present?
    assert_equal "Has Space", flash[:invalid_namespace_name]
  end

  test "duplicate name caught by validation returns alert" do
    sign_in_as(users(:admin))
    project = projects(:main_app)
    project.namespaces.create!(name: "racing")

    assert_no_difference "Namespace.count" do
      post project_namespaces_path(project), params: { namespace: { name: "racing" } }
    end
    assert flash[:alert].present?
  end

  test "rescues RecordNotUnique when validation is bypassed (true race)" do
    sign_in_as(users(:admin))
    project = projects(:main_app)
    project.namespaces.create!(name: "raced")

    uniqueness_validator = Namespace.validators_on(:name).find { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
    Namespace._validators[:name].delete(uniqueness_validator)
    Namespace.skip_callback(:validate, :before, uniqueness_validator)

    begin
      assert_no_difference "Namespace.count" do
        post project_namespaces_path(project), params: { namespace: { name: "raced" } }
      end
      assert_redirected_to project_path(project)
      assert_match(/already been taken/i, flash[:alert])
    ensure
      Namespace._validators[:name] << uniqueness_validator
      Namespace.set_callback(:validate, :before, uniqueness_validator)
    end
  end

  test "admin updates namespace" do
    sign_in_as(users(:admin))
    project = projects(:main_app)
    namespace = namespaces(:main_app_marketing)

    patch project_namespace_path(project, namespace), params: { namespace: { name: "marketing-v2" } }

    assert_redirected_to project_path(project)
    assert_equal "marketing-v2", namespace.reload.name
  end

  test "admin destroys namespace" do
    sign_in_as(users(:admin))
    project = projects(:main_app)
    namespace = project.namespaces.create!(name: "disposable")

    assert_difference "project.namespaces.count", -1 do
      delete project_namespace_path(project, namespace)
    end
    assert_redirected_to project_path(project)
  end

  test "404 on unknown project slug" do
    sign_in_as(users(:admin))
    post project_namespaces_path("does-not-exist"), params: { namespace: { name: "x" } }
    assert_response :not_found
  end

  test "namespace name with dots routes correctly" do
    sign_in_as(users(:admin))
    project = projects(:main_app)
    namespace = project.namespaces.create!(name: "marketing.cta")

    patch project_namespace_path(project, namespace), params: { namespace: { name: "marketing.cta.v2" } }
    assert_redirected_to project_path(project)
    assert_equal "marketing.cta.v2", namespace.reload.name
  end

  test "project show lists namespaces" do
    sign_in_as(users(:translator))
    get project_path(projects(:main_app))
    assert_response :success
    assert_select ".namespace-item", count: projects(:main_app).namespaces.count
  end

  test "project show hides admin actions for non-admin" do
    sign_in_as(users(:translator))
    get project_path(projects(:main_app))
    assert_select "button", text: /New namespace/, count: 0
    assert_select "dialog.modal", count: 0
  end

  test "project show shows new-namespace button for admin" do
    sign_in_as(users(:admin))
    get project_path(projects(:main_app))
    assert_select "button", text: /New namespace/
    assert_select "dialog.modal"
  end

  private
    def sign_in_as(user)
      token = user.sign_in_tokens.create!
      get sign_in_with_token_path(token: token.token)
    end
end
