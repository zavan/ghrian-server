require "test_helper"

class Api::V1::EnergyControllerTest < ActionDispatch::IntegrationTest
  def auth
    { "Authorization" => "Bearer #{RAW_API_TOKENS[:macos]}" }
  end

  # Fixtures: garage daily_summaries 2026-06-08 (generation 20) and 2026-06-09
  # (generation 12, feed_in 8, import 0.5, consumption 4). Tariff: import $0.30,
  # export $0.10. Pass an explicit date so tests don't depend on the real clock.
  DAY = "2026-06-09"

  test "requires a token" do
    get energy_api_v1_inverter_url(inverters(:garage))
    assert_response :unauthorized
  end

  test "per-inverter day totals and costs" do
    get energy_api_v1_inverter_url(inverters(:garage), period: "day", date: DAY), headers: auth
    assert_response :success

    body = response.parsed_body
    assert_equal inverters(:garage).id, body["inverter_id"]
    assert_equal "day", body["period"]
    assert_equal 12.0, body.dig("totals", "generation")
    assert_equal 4.0, body.dig("totals", "self_consumption") # 12 generated - 8 fed in
    assert_in_delta 0.15, body.dig("costs", "import_cost"), 0.001 # 0.5 kWh * $0.30
    assert_in_delta 0.80, body.dig("costs", "export_earnings"), 0.001 # 8 kWh * $0.10
    assert_in_delta 1.20, body.dig("costs", "savings"), 0.001 # self-consumed 4 kWh * $0.30
    assert_equal "$", body["currency"]
    assert_nil body["breakdown"] # day uses /intraday instead
  end

  test "month includes a breakdown series" do
    get energy_api_v1_inverter_url(inverters(:garage), period: "month", date: DAY), headers: auth
    assert_response :success

    body = response.parsed_body
    assert_equal 32.0, body.dig("totals", "generation") # 20 + 12 across the month
    assert_equal "day", body["breakdown_unit"]
    assert body["breakdown"].any? { |point| point["label"] == "9" && point["value"] == 12.0 }
  end

  test "site-wide energy sums every inverter" do
    get api_v1_energy_url(period: "lifetime"), headers: auth
    assert_response :success

    body = response.parsed_body
    assert_nil body["inverter_id"] # not scoped to one inverter
    assert_equal "lifetime", body["period"]
    assert_equal 32.0, body.dig("totals", "generation") # only garage has summaries
  end

  test "returns 404 for a missing inverter" do
    get energy_api_v1_inverter_url(id: 999_999), headers: auth
    assert_response :not_found
  end
end
