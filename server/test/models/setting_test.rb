require "test_helper"

class SettingTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  # Solid Cache persists across deploys, so a Setting row marshaled before a
  # migration deserializes with the old attribute set — reading a newer column
  # raised MissingAttributeError and broke `lb login` in production. The cache
  # key embeds the column set, so a stale entry is simply never read.
  test "current ignores a row cached before a migration added columns" do
    Setting.current # ensure the singleton row exists
    Rails.cache.clear
    Rails.cache.write("app_setting", Setting.select(:id).first) # the old fixed key, stale shape

    assert_equal 3, Setting.current.cli_token_limit
  end

  test "cache key derives from the column set, so schema changes rotate it" do
    assert_equal "app_setting/#{Digest::MD5.hexdigest(Setting.column_names.sort.join(","))}", Setting.cache_key
  end

  test "saving busts the cache so the next read sees the new value" do
    Setting.current.update!(cli_token_limit: 7)
    assert_equal 7, Setting.current.cli_token_limit
  end
end
