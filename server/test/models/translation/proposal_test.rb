require "test_helper"

class Translation::ProposalTest < ActiveSupport::TestCase
  setup do
    @project = projects(:main_app)
    @namespace = namespaces(:main_app_common)
    @locale = locales(:main_app_en)
    @proposer = users(:translator)
    @reviewer = users(:admin)
  end

  def propose(key:, value:)
    Translation::Proposal.propose(namespace: @namespace, key: key, locale: @locale, value: value, author: @proposer)
  end

  test "propose upserts one row per (namespace, key, locale)" do
    propose(key: "welcome", value: "Hi")
    assert_no_difference -> { Translation::Proposal.count } do
      propose(key: "welcome", value: "Hello")
    end
    assert_equal "Hello", Translation::Proposal.last.value
  end

  test "different sessions keep separate proposals for the same key" do
    a = Translation::Proposal.propose(namespace: @namespace, key: "welcome", locale: @locale, value: "Hi", author: @proposer, session: "branch-a")
    b = Translation::Proposal.propose(namespace: @namespace, key: "welcome", locale: @locale, value: "Yo", author: @proposer, session: "branch-b")

    assert_not_equal a.id, b.id
    assert_equal 2, Translation::Proposal.where(namespace: @namespace, key: "welcome").count
  end

  test "new_key? and current_value expose the diff against the live value" do
    fresh = propose(key: "brand.new", value: "x")
    assert fresh.new_key?
    assert_nil fresh.current_value

    existing = propose(key: "greeting", value: "Hey")
    assert_not existing.new_key?
    assert_equal "Hello", existing.current_value
  end

  test "accept materialises a draft authored by the proposer and clears the proposal" do
    proposal = propose(key: "welcome", value: "Hi")

    translation = nil
    assert_difference -> { Translation::Proposal.count }, -1 do
      translation = proposal.accept(by: @reviewer)
    end

    assert_equal "Hi", translation.value
    assert_equal @proposer, translation.author, "keeps the proposer as the text author"
    assert translation.draft?, "accepted proposals become drafts, never published"
    assert_equal "welcome", translation.translation_key.key
  end

  test "accept records who accepted" do
    proposal = propose(key: "welcome", value: "Hi")
    translation = proposal.accept(by: @reviewer)
    event = translation.events.find_by(action: "proposal_accepted")
    assert_equal @reviewer, event.creator
  end

  test "accepting a proposal for a published key overwrites it back to draft" do
    translations(:greeting_en).publish(by: @reviewer)
    proposal = propose(key: "greeting", value: "Hey")

    proposal.accept(by: @reviewer)

    greeting = translations(:greeting_en).reload
    assert_equal "Hey", greeting.value
    assert greeting.draft?, "an explicit human accept may unpublish the live value"
  end

  test "reject discards the proposal and records the dismissal" do
    proposal = propose(key: "welcome", value: "Hi")
    assert_difference -> { Translation::Proposal.count }, -1 do
      proposal.reject(by: @reviewer)
    end
    assert @project.events.exists?(action: "proposal_rejected")
  end

  test "a proposal and its locale must share a project" do
    proposal = Translation::Proposal.new(namespace: @namespace, key: "x", value: "y",
      locale: locales(:marketing_site_en), author: @proposer)
    assert_not proposal.valid?
    assert_includes proposal.errors[:locale], "must belong to the same project as the namespace"
  end
end
