require "test_helper"

class Projects::MissingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:main_app)
    @report = @project.missing_key_reports.create!(
      namespace: "emails", key: "welcome.subject", hits: 3, locales: %w[ en pt-BR ], last_reported_at: Time.current
    )
  end

  test "lists reported missing keys" do
    sign_in_as(users(:translator))
    get project_missing_index_path(@project)
    assert_response :success
    assert_select "h2", "Missing translations"
  end

  test "promote creates a real key with empty translations and removes the report" do
    sign_in_as(users(:translator))
    assert_difference -> { @project.translation_keys.count }, 1 do
      assert_difference -> { @project.missing_key_reports.count }, -1 do
        post project_missing_promotion_path(@project, @report)
      end
    end
    assert_redirected_to project_missing_index_path(@project)

    namespace = @project.namespaces.find_by(name: "emails")
    key = @project.translation_keys.find_by(namespace: namespace, key: "welcome.subject")
    assert_not_nil key
    assert_equal %w[ en pt-BR ].sort, key.translations.map { |t| t.locale.code }.sort
    assert key.translations.all? { |t| t.value.nil? }, "promoted translations start empty"
  end

  test "ignore removes the report" do
    sign_in_as(users(:translator))
    assert_difference -> { @project.missing_key_reports.count }, -1 do
      delete project_missing_path(@project, @report)
    end
    assert_redirected_to project_missing_index_path(@project)
  end

  test "viewers cannot promote or ignore" do
    sign_in_as(users(:viewer))
    post project_missing_promotion_path(@project, @report)
    assert_response :forbidden
    delete project_missing_path(@project, @report)
    assert_response :forbidden
  end
end
