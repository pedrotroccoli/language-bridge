require "test_helper"

class Translation::QaTest < ActiveSupport::TestCase
  test "extracts interpolation placeholders" do
    assert_equal %w[ {count} {{name}} ], Translation::Qa.placeholders("Hi {{name}}, you have {count}").sort
  end

  test "flags a placeholder mismatch with the source" do
    source = Translation.new(value: "Hello {{name}}")
    translation = Translation.new(value: "Olá")
    assert_includes Translation::Qa.warnings(translation, source), "Placeholders differ from the source"
  end

  test "no placeholder warning when they match" do
    source = Translation.new(value: "Hello {{name}}")
    translation = Translation.new(value: "Olá {{name}}")
    assert_not_includes Translation::Qa.warnings(translation, source), "Placeholders differ from the source"
  end

  test "flags a wild length difference" do
    source = Translation.new(value: "Short label here")
    translation = Translation.new(value: "x" * 200)
    assert_includes Translation::Qa.warnings(translation, source), "Length looks off vs the source"
  end

  test "blank translation has no warnings" do
    assert_empty Translation::Qa.warnings(Translation.new(value: ""), Translation.new(value: "Hello {{n}}"))
  end

  test "fuzzy when source is newer than the translation" do
    translation = Translation.new(value: "Olá", updated_at: 2.days.ago)
    source = Translation.new(value: "Hello", updated_at: 1.hour.ago)
    assert Translation::Qa.fuzzy?(translation, source)
  end

  test "not fuzzy when the translation is newer" do
    translation = Translation.new(value: "Olá", updated_at: 1.hour.ago)
    source = Translation.new(value: "Hello", updated_at: 2.days.ago)
    assert_not Translation::Qa.fuzzy?(translation, source)
  end

  test "namespace qa_overview counts warnings against the source locale" do
    namespace = namespaces(:main_app_common)
    source = locales(:main_app_en)
    source.mark_as_source!

    key = namespace.translation_keys.create!(project: projects(:main_app), key: "qa.check")
    key.set_translation(locale: source, value: "Hello {{name}}", author: users(:admin))
    key.set_translation(locale: locales(:main_app_pt_br), value: "Olá", author: users(:admin)) # missing placeholder

    assert_equal 1, namespace.qa_overview(source)[:warnings]
  end
end
