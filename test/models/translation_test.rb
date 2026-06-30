require "test_helper"

class TranslationTest < ActiveSupport::TestCase
  test "valid with translation_key and locale" do
    translation = Translation.new(translation_key: translation_keys(:main_app_common_farewell), locale: locales(:main_app_pt_br), value: "Adeus")
    assert translation.valid?
  end

  test "assigns project from the translation key on create" do
    translation = Translation.create!(translation_key: translation_keys(:main_app_common_farewell),
                                      locale: locales(:main_app_pt_br), value: "Adeus")
    assert_equal projects(:main_app), translation.project
  end

  test "rejects a key and locale from different projects" do
    translation = Translation.new(translation_key: translation_keys(:main_app_common_greeting),
                                  locale: locales(:marketing_site_en), value: "x")
    assert_not translation.valid?
    assert_includes translation.errors[:locale], "must belong to the same project as the key"
  end

  test "requires translation_key" do
    translation = Translation.new(locale: locales(:main_app_en))
    assert_not translation.valid?
    assert_includes translation.errors[:translation_key], "must exist"
  end

  test "requires locale" do
    translation = Translation.new(translation_key: translation_keys(:main_app_common_greeting))
    assert_not translation.valid?
    assert_includes translation.errors[:locale], "must exist"
  end

  test "author optional" do
    translation = Translation.new(translation_key: translation_keys(:main_app_common_farewell), locale: locales(:main_app_pt_br), value: "Adeus")
    assert_nil translation.author
    assert translation.valid?
  end

  test "unique per translation_key and locale" do
    existing = translations(:greeting_en)
    duplicate = Translation.new(translation_key: existing.translation_key, locale: existing.locale, value: "Hi")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:translation_key_id], "has already been taken"
  end

  test "counter cache increments translation_key and locale on create" do
    key = translation_keys(:marketing_site_common_cta)
    locale = locales(:marketing_site_en)
    assert_difference [ -> { key.reload.translations_count }, -> { locale.reload.translations_count } ], 1 do
      Translation.create!(translation_key: key, locale: locale, value: "Buy now")
    end
  end

  test "counter cache decrements on destroy" do
    translation = translations(:greeting_pt)
    key = translation.translation_key
    locale = translation.locale
    assert_difference [ -> { key.reload.translations_count }, -> { locale.reload.translations_count } ], -1 do
      translation.destroy!
    end
  end

  test "untranslated scope returns translations with nil value" do
    assert_includes Translation.untranslated, translations(:farewell_en_missing)
    assert_not_includes Translation.untranslated, translations(:greeting_en)
  end

  test "snapshots prior value into a version on value change" do
    translation = translations(:greeting_en)
    translation.update_column(:author_id, users(:admin).id)
    assert_difference -> { translation.versions.count }, 1 do
      translation.update!(value: "Hi there")
    end
    version = translation.versions.order(:created_at).last
    assert_equal "Hello", version.value
    assert_equal users(:admin), version.author
  end

  test "does not snapshot when value unchanged" do
    translation = translations(:greeting_en)
    assert_no_difference -> { translation.versions.count } do
      translation.update!(updated_at: Time.current)
    end
  end

  test "editing the value discards the publication and returns to draft" do
    translation = translations(:greeting_en)
    Translation::Publication.create!(translation: translation)
    assert translation.reload.published?

    translation.update!(value: "Changed")

    assert_nil translation.reload.publication
    assert translation.draft?
  end

  test "draft? is true only with a value and no publication" do
    translation = translations(:greeting_en) # has value, no publication
    assert translation.draft?
    Translation::Publication.create!(translation: translation)
    assert_not translation.reload.draft?
    assert_not translations(:farewell_en_missing).draft? # blank value
  end

  test "publishing records an event crediting the publisher" do
    translation = translations(:greeting_pt)
    assert_difference -> { translation.events.where(action: "published").count }, 1 do
      translation.publish(by: users(:admin))
    end
    assert_equal users(:admin), translation.events.where(action: "published").last.creator
  end

  test "editing a published value records an unpublished event" do
    Current.session = sessions(:admin_session)
    translation = translations(:greeting_en)
    translation.publish(by: users(:admin))

    assert_difference -> { translation.events.where(action: "unpublished").count }, 1 do
      translation.update!(value: "Changed")
    end
    assert_equal "value_changed", translation.events.where(action: "unpublished").last.metadata["reason"]
  end

  test "published and unpublished scopes" do
    published = translations(:greeting_en)
    Translation::Publication.create!(translation: published, publisher: users(:admin))
    assert_includes Translation.published, published
    assert_not_includes Translation.published, translations(:greeting_pt)
    assert_includes Translation.unpublished, translations(:greeting_pt)
    assert_not_includes Translation.unpublished, published
  end

  test "approved scope" do
    approved = translations(:greeting_en)
    Translation::Approval.create!(translation: approved, approver: users(:admin))
    assert_includes Translation.approved, approved
    assert_not_includes Translation.approved, translations(:greeting_pt)
  end

  test "under_review scope" do
    reviewed = translations(:greeting_en)
    Translation::Review.create!(translation: reviewed, requester: users(:admin))
    assert_includes Translation.under_review, reviewed
    assert_not_includes Translation.under_review, translations(:greeting_pt)
  end

  test "destroys dependent state records and versions" do
    translation = translations(:greeting_en)
    Translation::Publication.create!(translation: translation, publisher: users(:admin))
    Translation::Review.create!(translation: translation, requester: users(:admin))
    Translation::Approval.create!(translation: translation, approver: users(:admin))
    translation.update!(value: "changed")

    translation.destroy!

    assert_equal 0, Translation::Publication.where(translation_id: translation.id).count
    assert_equal 0, Translation::Review.where(translation_id: translation.id).count
    assert_equal 0, Translation::Approval.where(translation_id: translation.id).count
    assert_equal 0, Translation::Version.where(translation_id: translation.id).count
  end

  test "track_event records an event" do
    translation = translations(:greeting_en)
    assert_difference -> { translation.events.count }, 1 do
      translation.track_event("published", metadata: { locale: "en" })
    end
    event = translation.events.last
    assert_equal "published", event.action
    assert_equal({ "locale" => "en" }, event.metadata)
  end

  test "request_review marks under review and is idempotent" do
    translation = translations(:greeting_en)
    assert_difference -> { Translation::Review.count }, 1 do
      translation.request_review(by: users(:translator))
    end
    assert translation.under_review?
    assert_no_difference -> { Translation::Review.count } do
      translation.request_review(by: users(:translator))
    end
  end

  test "approve clears any pending review" do
    translation = translations(:greeting_en)
    translation.request_review(by: users(:translator))

    translation.approve(by: users(:admin))

    assert translation.approved?
    assert_not translation.under_review?
  end

  test "editing the value resets review and approval" do
    translation = translations(:greeting_en)
    translation.request_review(by: users(:translator))
    translation.approve(by: users(:admin))

    translation.update!(value: "Changed", author: users(:translator))

    assert_not translation.reload.under_review?
    assert_not translation.approved?
  end
end
