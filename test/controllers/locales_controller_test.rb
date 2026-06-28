require "test_helper"

class LocalesControllerTest < ActionDispatch::IntegrationTest
  test "redirects to sign_in when unauthenticated" do
    post project_locales_path(projects(:main_app)), params: { locale: { code: "fr" } }
    assert_redirected_to sign_in_path
  end

  test "non-admin cannot create/update/destroy" do
    sign_in_as(users(:translator))
    project = projects(:main_app)

    assert_no_difference "Locale.count" do
      post project_locales_path(project), params: { locale: { code: "fr" } }
    end
    assert_response :forbidden

    patch project_locale_path(project, locales(:main_app_en)), params: { locale: { code: "xx" } }
    assert_response :forbidden

    delete project_locale_path(project, locales(:main_app_en))
    assert_response :forbidden
  end

  test "admin creates locale" do
    sign_in_as(users(:admin))
    project = projects(:main_app)

    assert_difference "project.locales.count", 1 do
      post project_locales_path(project), params: { locale: { code: "fr" } }
    end
    assert_redirected_to project_path(project)
    assert_match(/Locale created/, flash[:notice])
    assert project.locales.exists?(code: "fr")
  end

  test "admin adds multiple locales at once" do
    sign_in_as(users(:admin))
    project = projects(:main_app)

    assert_difference "project.locales.count", 2 do
      post project_locales_path(project), params: { locale: { codes: [ "fr", "de" ] } }
    end
    assert_redirected_to project_path(project)
    assert_match(/Added 2 locales/, flash[:notice])
    assert project.locales.exists?(code: "fr")
    assert project.locales.exists?(code: "de")
  end

  test "bulk add skips duplicates and reports them" do
    sign_in_as(users(:admin))
    project = projects(:main_app)
    existing = locales(:main_app_en).code

    assert_difference "project.locales.count", 1 do
      post project_locales_path(project), params: { locale: { codes: [ "it", existing ] } }
    end
    assert_redirected_to project_path(project)
    assert_match(/skipped/, flash[:notice])
  end

  test "admin sees alert on duplicate code" do
    sign_in_as(users(:admin))
    project = projects(:main_app)

    assert_no_difference "Locale.count" do
      post project_locales_path(project), params: { locale: { code: locales(:main_app_en).code } }
    end
    assert_redirected_to project_path(project)
    assert flash[:alert].present?
    assert_equal locales(:main_app_en).code, flash[:invalid_locale_code]
  end

  test "admin updates locale code" do
    sign_in_as(users(:admin))
    project = projects(:main_app)
    locale = locales(:main_app_en)

    patch project_locale_path(project, locale), params: { locale: { code: "en-GB" } }
    assert_redirected_to project_path(project)
    assert_equal "en-GB", locale.reload.code
  end

  test "admin destroys locale" do
    sign_in_as(users(:admin))
    project = projects(:main_app)
    locale = project.locales.create!(code: "zz")

    assert_difference "project.locales.count", -1 do
      delete project_locale_path(project, locale)
    end
    assert_redirected_to project_path(project)
  end

  test "rejects a malformed locale code" do
    sign_in_as(users(:admin))
    project = projects(:main_app)

    assert_no_difference "Locale.count" do
      post project_locales_path(project), params: { locale: { code: "not a code!" } }
    end
    assert_redirected_to project_path(project)
    assert flash[:alert].present?
  end

  test "bulk add skips malformed codes" do
    sign_in_as(users(:admin))
    project = projects(:main_app)

    assert_difference "project.locales.count", 1 do
      post project_locales_path(project), params: { locale: { codes: [ "ja", "<script>" ] } }
    end
    assert project.locales.exists?(code: "ja")
    assert_not project.locales.exists?(code: "<script>")
  end
end
