require "test_helper"

class ProjectDeliveryTemplateTest < ActiveSupport::TestCase
  setup do
    @project = projects(:main_app)
    @namespace = namespaces(:main_app_common)   # name: common
    @locale = locales(:main_app_pt_br)          # code: pt-BR
  end

  test "default template is project-scoped" do
    assert_equal "{project_slug}/{namespace}/{locale}.json", Project.new(name: "X").delivery_path_template
  end

  test "delivery_key_for renders all tokens" do
    @project.update!(delivery_path_template: "{project_slug}/{namespace}/{locale}.json")
    assert_equal "main-app/common/pt-BR.json", @project.delivery_key_for(@namespace, @locale)
  end

  test "delivery_key_for honors a custom template" do
    @project.update!(delivery_path_template: "i18n/{locale}/{namespace}.json")
    assert_equal "i18n/pt-BR/common.json", @project.delivery_key_for(@namespace, @locale)
  end

  test "rejects a leading slash" do
    @project.delivery_path_template = "/{namespace}/{locale}.json"
    assert_not @project.valid?
    assert_match(/must not start with/, @project.errors[:delivery_path_template].join)
  end

  test "rejects an unknown token" do
    @project.delivery_path_template = "{bucket}/{namespace}/{locale}.json"
    assert_not @project.valid?
    assert_match(/unknown token \{bucket\}/, @project.errors[:delivery_path_template].join)
  end

  test "requires {namespace} and {locale}" do
    @project.delivery_path_template = "{project_slug}/{locale}.json"
    assert_not @project.valid?
    assert_match(/must include \{namespace\}/, @project.errors[:delivery_path_template].join)

    @project.delivery_path_template = "{project_slug}/{namespace}.json"
    assert_not @project.valid?
    assert_match(/must include \{locale\}/, @project.errors[:delivery_path_template].join)
  end

  test "rejects invalid literal characters" do
    @project.delivery_path_template = "{namespace}/{locale} space.json"
    assert_not @project.valid?
    assert_match(/invalid characters/, @project.errors[:delivery_path_template].join)
  end
end
