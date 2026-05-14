require "test_helper"

class NamespacesControllerTest < ActionDispatch::IntegrationTest
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
