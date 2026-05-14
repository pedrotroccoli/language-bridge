require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to sign_in when unauthenticated" do
    get projects_path
    assert_redirected_to sign_in_path
  end

  test "translator can list and view projects" do
    sign_in_as(users(:translator))

    get projects_path
    assert_response :success
    assert_select "a", text: "New project", count: 0

    get project_path(projects(:main_app))
    assert_response :success
    assert_select ".page-header__actions", count: 0
  end

  test "viewer can list and view projects" do
    sign_in_as(users(:viewer))

    get projects_path
    assert_response :success

    get project_path(projects(:main_app))
    assert_response :success
  end

  test "non-admin cannot reach new/edit/create/update/destroy" do
    sign_in_as(users(:translator))

    get new_project_path
    assert_response :forbidden

    get edit_project_path(projects(:main_app))
    assert_response :forbidden

    assert_no_difference "Project.count" do
      post projects_path, params: { project: { name: "Sneaky" } }
    end
    assert_response :forbidden

    patch project_path(projects(:main_app)), params: { project: { name: "Hijacked" } }
    assert_response :forbidden
    assert_equal "Main App", projects(:main_app).reload.name

    assert_no_difference "Project.count" do
      delete project_path(projects(:main_app))
    end
    assert_response :forbidden
  end

  test "admin creates project with auto-generated slug" do
    sign_in_as(users(:admin))

    assert_difference "Project.count", 1 do
      post projects_path, params: { project: { name: "Hello World" } }
    end

    project = Project.find_by!(slug: "hello-world")
    assert_equal "Hello World", project.name
    assert_redirected_to project_path(project)
    assert_match(/Project created/, flash[:notice])
  end

  test "admin sees errors when creating with blank name" do
    sign_in_as(users(:admin))

    assert_no_difference "Project.count" do
      post projects_path, params: { project: { name: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "admin updates project name" do
    sign_in_as(users(:admin))
    project = projects(:main_app)
    original_slug = project.slug

    patch project_path(project), params: { project: { name: "Renamed App" } }

    assert_redirected_to project_path(project)
    project.reload
    assert_equal "Renamed App", project.name
    assert_equal original_slug, project.slug
  end

  test "admin sees errors when updating with blank name" do
    sign_in_as(users(:admin))

    patch project_path(projects(:main_app)), params: { project: { name: "" } }
    assert_response :unprocessable_entity
  end

  test "admin destroys project" do
    sign_in_as(users(:admin))
    project = Project.create!(name: "Disposable")

    assert_difference "Project.count", -1 do
      delete project_path(project)
    end
    assert_redirected_to projects_path
  end

  test "404 on unknown slug" do
    sign_in_as(users(:admin))
    get project_path("does-not-exist")
    assert_response :not_found
  end

  test "root routes to projects index" do
    sign_in_as(users(:viewer))
    get root_path
    assert_response :success
    assert_select "h1", "Projects"
  end

  private
    def sign_in_as(user)
      token = user.sign_in_tokens.create!
      get sign_in_with_token_path(token: token.token)
    end
end
