require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "a token is generated on create and only its digest is stored" do
    token = users(:one).api_tokens.create!(name: "new client")

    assert token.token.present?
    assert token.token.start_with?("ghr_")
    assert_equal ApiToken.digest(token.token), token.token_digest
    assert_equal token.token[0, 12], token.token_prefix
  end

  test "the plaintext token is not recoverable from a freshly loaded record" do
    token = users(:one).api_tokens.create!(name: "new client")
    assert_nil ApiToken.find(token.id).token
  end

  test "authenticate finds the token by digest and stamps last_used_at" do
    record = api_tokens(:cli) # no last_used_at in fixture
    found = ApiToken.authenticate(RAW_API_TOKENS[:cli])
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
