require "test_helper"

class MachineTranslationTest < ActiveSupport::TestCase
  test "stub provider tags the text with the target locale" do
    assert_equal "[pt-BR] Hello", MachineTranslation.translate("Hello", from: "en", to: "pt-BR")
  end

  test "blank input round-trips" do
    assert_equal "", MachineTranslation.translate("", from: "en", to: "fr")
  end
end
