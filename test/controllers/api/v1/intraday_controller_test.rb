require "test_helper"

class Api::V1::IntradayControllerTest < ActionDispatch::IntegrationTest
  def auth
    { "Authorization" => "Bearer #{RAW_API_TOKENS[:macos]}" }
  end

  test "requires a token" do
    get intraday_api_v1_inverter_url(inverters(:garage))
    assert_response :unauthorized
  end

  test "returns named power series plus an soc series" do
    get intraday_api_v1_inverter_url(inverters(:garage)), headers: auth
    assert_response :success

    body = response.parsed_body
    assert_equal inverters(:garage).id, body["inverter_id"]
    assert_equal Date.current.to_s, body["date"]
    assert_equal %w[PV Grid Load Battery], body["power"].map { |s| s["name"] }
    assert_equal "SOC", body.dig("soc", 0, "name")
    # Today's readings carry battery_soc, so the SOC series has points; each is [time, %].
    assert_equal [ 78, 80 ], body.dig("soc", 0, "data").map { |point| point.last }
  end

  test "scopes to the requested date" do
    get intraday_api_v1_inverter_url(inverters(:garage), date: "2000-01-01"), headers: auth
    assert_response :success

    body = response.parsed_body
    assert_equal "2000-01-01", body["date"]
    assert_empty body.dig("soc", 0, "data")
  end

  test "returns 404 for a missing inverter" do
    get intraday_api_v1_inverter_url(id: 999_999), headers: auth
    assert_response :not_found
  end
end
