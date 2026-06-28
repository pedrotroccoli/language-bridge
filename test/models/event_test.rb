require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "valid with eventable and action" do
    event = Event.new(eventable: translations(:greeting_en), action: "created")
    assert event.valid?
  end

  test "requires eventable" do
    event = Event.new(action: "created")
    assert_not event.valid?
    assert_includes event.errors[:eventable], "must exist"
  end

  test "requires action" do
    event = Event.new(eventable: translations(:greeting_en))
    assert_not event.valid?
    assert_includes event.errors[:action], "can't be blank"
  end

  test "creator optional" do
    event = Event.new(eventable: translations(:greeting_en), action: "created")
    assert event.valid?
  end

  test "metadata defaults to empty hash" do
    event = Event.create!(eventable: translations(:greeting_en), action: "created")
    assert_equal({}, event.metadata)
  end

  test "defaults creator to Current.user" do
    Current.session = sessions(:admin_session)
    event = Event.create!(eventable: translations(:greeting_en), action: "created")
    assert_equal users(:admin), event.creator
  end

  test "polymorphic across eventable types" do
    translation_event = Event.create!(eventable: translations(:greeting_en), action: "created")
    key_event = Event.create!(eventable: translation_keys(:main_app_common_greeting), action: "created")
    project_event = Event.create!(eventable: projects(:main_app), action: "created")

    assert_equal "Translation", translation_event.eventable_type
    assert_equal "TranslationKey", key_event.eventable_type
    assert_equal "Project", project_event.eventable_type
  end

  test "track_event helper creates an event with creator" do
    Current.session = sessions(:admin_session)
    key = translation_keys(:main_app_common_greeting)
    event = key.track_event("renamed", metadata: { from: "greeting" })
    assert_equal "renamed", event.action
    assert_equal users(:admin), event.creator
    assert_equal({ "from" => "greeting" }, event.metadata)
  end
end
