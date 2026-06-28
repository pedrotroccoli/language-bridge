require "test_helper"

class Translation::VersionTest < ActiveSupport::TestCase
  test "valid with translation" do
    version = Translation::Version.new(translation: translations(:greeting_en), value: "old")
    assert version.valid?
  end

  test "requires translation" do
    version = Translation::Version.new(value: "old")
    assert_not version.valid?
    assert_includes version.errors[:translation], "must exist"
  end

  test "author optional" do
    version = Translation::Version.new(translation: translations(:greeting_en), value: "old")
    assert_nil version.author
    assert version.valid?
  end

  test "value may be nil" do
    version = Translation::Version.new(translation: translations(:greeting_en), value: nil)
    assert version.valid?
  end

  test "created by translation value change carries prior value and author" do
    translation = translations(:greeting_en)
    translation.update_column(:author_id, users(:admin).id)
    translation.update!(value: "Hi", author: users(:translator))
    version = translation.versions.order(:created_at).last
    assert_equal "Hello", version.value
    assert_equal users(:admin), version.author
  end
end
