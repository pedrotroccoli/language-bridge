require "test_helper"

class Translation::ApprovalTest < ActiveSupport::TestCase
  test "valid with translation and approver" do
    approval = Translation::Approval.new(translation: translations(:greeting_pt), approver: users(:admin))
    assert approval.valid?
  end

  test "requires translation" do
    approval = Translation::Approval.new(approver: users(:admin))
    assert_not approval.valid?
    assert_includes approval.errors[:translation], "must exist"
  end

  test "requires approver" do
    Current.session = nil
    approval = Translation::Approval.new(translation: translations(:greeting_pt))
    assert_not approval.valid?
    assert_includes approval.errors[:approver], "must exist"
  end

  test "one approval per translation" do
    Translation::Approval.create!(translation: translations(:greeting_pt), approver: users(:admin))
    duplicate = Translation::Approval.new(translation: translations(:greeting_pt), approver: users(:translator))
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "defaults approver to Current.user" do
    Current.session = sessions(:admin_session)
    approval = Translation::Approval.create!(translation: translations(:greeting_pt))
    assert_equal users(:admin), approval.approver
  end

  test "touches translation on create" do
    translation = translations(:greeting_pt)
    translation.update_column(:updated_at, 1.day.ago)
    before = translation.reload.updated_at
    Translation::Approval.create!(translation: translation, approver: users(:admin))
    assert_operator translation.reload.updated_at, :>, before
  end
end
