require "test_helper"

class Api::V1::InvertersControllerTest < ActionDispatch::IntegrationTest
  def auth(token = RAW_API_TOKENS[:macos])
    { "Authorization" => "Bearer #{token}" }
  end

  test "requires a token" do
    get api_v1_inverters_url
    assert_response :unauthorized
  end

  test "rejects an unknown token" do
    get api_v1_inverters_url, headers: auth("bogus")
    assert_response :unauthorized
  end

  test "lists inverters with a valid token" do
    get api_v1_inverters_url, headers: auth
    assert_response :success

    body = response.parsed_body
    assert_equal Inverter.count, body["inverters"].size
    assert(body["inverters"].any? { |i| i["mqtt_topic"] == "ghrian/inverter/01" })
  end

  test "shows an inverter with its latest snapshot" do
    get api_v1_inverter_url(inverters(:garage)), headers: auth
    assert_response :success
    assert_equal 80, response.parsed_body.dig("inverter", "latest_values", "battery_soc", "value")
  end

  test "includes a computed snapshot block" do
    get api_v1_inverter_url(inverters(:garage)), headers: auth
    assert_response :success

    snapshot = response.parsed_body.dig("inverter", "snapshot")
    assert_equal %w[pv grid battery load], snapshot["flows"].keys
    assert_equal "in", snapshot.dig("flows", "pv", "direction")
    assert_equal 80, snapshot["battery_soc"]
    assert snapshot["today"].key?("yield")
  end

  test "returns 404 for a missing inverter" do
    get api_v1_inverter_url(id: 999_999), headers: auth
    assert_response :not_found
  end

  test "authenticating stamps the token's last_used_at" do
    token = api_tokens(:cli)
    get api_v1_inverters_url, headers: auth(RAW_API_TOKENS[:cli])
    assert_not_nil token.reload.last_used_at
  end
end
