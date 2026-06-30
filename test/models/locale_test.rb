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

  test "mark_as_source sets the project source locale" do
    locale = locales(:main_app_en)
    locale.mark_as_source!
    assert locale.reload.is_source
    assert_equal locale, projects(:main_app).source_locale
  end

  test "mark_as_source clears the previous source in the same project" do
    previous = locales(:main_app_en).tap(&:mark_as_source!)
    locales(:main_app_pt_br).mark_as_source!
    assert_not previous.reload.is_source
    assert_equal locales(:main_app_pt_br), projects(:main_app).reload.source_locale
  end

  test "only one source allowed per project" do
    locales(:main_app_en).update!(is_source: true)
    assert_raises(ActiveRecord::RecordNotUnique) do
      locales(:main_app_pt_br).update_columns(is_source: true)
    end
  end
end
