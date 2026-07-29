require "test_helper"

class Translation::PublicationTest < ActiveSupport::TestCase
  test "valid with translation" do
    publication = Translation::Publication.new(translation: translations(:greeting_pt))
    assert publication.valid?
  end

  test "requires translation" do
    publication = Translation::Publication.new
    assert_not publication.valid?
    assert_includes publication.errors[:translation], "must exist"
  end

  test "publisher optional" do
    publication = Translation::Publication.new(translation: translations(:greeting_pt))
    assert publication.valid?
  end

  test "one publication per translation" do
    Translation::Publication.create!(translation: translations(:greeting_pt))
    duplicate = Translation::Publication.new(translation: translations(:greeting_pt))
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "defaults publisher to Current.user" do
    Current.session = sessions(:admin_session)
    publication = Translation::Publication.create!(translation: translations(:greeting_pt))
    assert_equal users(:admin), publication.publisher
  end

  test "touches translation on create" do
    translation = translations(:greeting_pt)
    translation.update_column(:updated_at, 1.day.ago)
    before = translation.reload.updated_at
    Translation::Publication.create!(translation: translation)
    assert_operator translation.reload.updated_at, :>, before
  end
end
