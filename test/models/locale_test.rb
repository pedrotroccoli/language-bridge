require "test_helper"

class LocaleTest < ActiveSupport::TestCase
  test "valid with project and code" do
    locale = Locale.new(project: projects(:main_app), code: "fr")
    assert locale.valid?
  end

  test "requires project" do
    locale = Locale.new(code: "fr")
    assert_not locale.valid?
    assert_includes locale.errors[:project], "must exist"
  end

  test "requires code" do
    locale = Locale.new(project: projects(:main_app))
    assert_not locale.valid?
    assert_includes locale.errors[:code], "can't be blank"
  end

  test "code unique per project" do
    duplicate = Locale.new(project: projects(:main_app), code: locales(:main_app_en).code)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "same code allowed across different projects" do
    locale = Locale.new(project: projects(:marketing_site), code: locales(:main_app_pt_br).code)
    assert locale.valid?
  end

  test "counter cache increments project.locales_count on create" do
    project = Project.create!(name: "Counter Test")
    assert_difference -> { project.reload.locales_count }, 1 do
      project.locales.create!(code: "en")
    end
  end

  test "counter cache decrements project.locales_count on destroy" do
    project = Project.create!(name: "Counter Decrement")
    locale = project.locales.create!(code: "en")
    assert_difference -> { project.reload.locales_count }, -1 do
      locale.destroy!
    end
  end

  test "destroys dependent translations" do
    locale = locales(:main_app_en)
    assert_difference -> { Translation.count }, -locale.translations.count do
      locale.destroy!
    end
  end
end
