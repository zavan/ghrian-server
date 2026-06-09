require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "a token is generated on create" do
    token = users(:one).api_tokens.create!(name: "new client")
    assert token.token.present?
  end

  test "authenticate returns the token and stamps last_used_at" do
    record = api_tokens(:cli) # no last_used_at in fixture
    found = ApiToken.authenticate(record.token)
    assert_equal record, found
    assert_not_nil found.last_used_at
  end

  test "authenticate returns nil for unknown or blank tokens" do
    assert_nil ApiToken.authenticate("does-not-exist")
    assert_nil ApiToken.authenticate("")
    assert_nil ApiToken.authenticate(nil)
  end

  test "name is required" do
    assert_not users(:one).api_tokens.new.valid?
  end
end
