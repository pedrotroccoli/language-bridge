require "test_helper"

class Translation::ReviewTest < ActiveSupport::TestCase
  test "valid with translation and requester" do
    review = Translation::Review.new(translation: translations(:greeting_pt), requester: users(:translator))
    assert review.valid?
  end

  test "requires translation" do
    review = Translation::Review.new(requester: users(:translator))
    assert_not review.valid?
    assert_includes review.errors[:translation], "must exist"
  end

  test "requires requester" do
    Current.session = nil
    review = Translation::Review.new(translation: translations(:greeting_pt))
    assert_not review.valid?
    assert_includes review.errors[:requester], "must exist"
  end

  test "one review per translation" do
    Translation::Review.create!(translation: translations(:greeting_pt), requester: users(:translator))
    duplicate = Translation::Review.new(translation: translations(:greeting_pt), requester: users(:admin))
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "defaults requester to Current.user" do
    Current.session = sessions(:admin_session)
    review = Translation::Review.create!(translation: translations(:greeting_pt))
    assert_equal users(:admin), review.requester
  end

  test "touches translation on create" do
    translation = translations(:greeting_pt)
    translation.update_column(:updated_at, 1.day.ago)
    before = translation.reload.updated_at
    Translation::Review.create!(translation: translation, requester: users(:translator))
    assert_operator translation.reload.updated_at, :>, before
  end
end
