require "test_helper"

class Api::V1::ReadingsControllerTest < ActionDispatch::IntegrationTest
  def auth
    { "Authorization" => "Bearer #{api_tokens(:macos).token}" }
  end

  test "requires a token" do
    get api_v1_inverter_readings_url(inverters(:garage))
    assert_response :unauthorized
  end

  test "returns full readings by default" do
    get api_v1_inverter_readings_url(inverters(:garage)), headers: auth
    assert_response :success

    body = response.parsed_body
    assert_equal 2, body["readings"].size
    assert body["readings"].first.key?("values")
  end

  test "metric filter returns a compact chronological series" do
    get api_v1_inverter_readings_url(inverters(:garage), metric: "battery_soc"), headers: auth
    assert_response :success

    body = response.parsed_body
    assert_equal "battery_soc", body["metric"]
    assert_equal [ 78, 80 ], body["readings"].map { |r| r["value"] }
    assert_equal %w[% %], body["readings"].map { |r| r["unit"] }
  end

  test "from filter limits the range" do
    get api_v1_inverter_readings_url(inverters(:garage), from: 90.minutes.ago.iso8601), headers: auth
    assert_response :success
    assert_equal 1, response.parsed_body["readings"].size
  end
end
