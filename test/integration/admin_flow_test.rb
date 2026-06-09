require "test_helper"

class AdminFlowTest < ActionDispatch::IntegrationTest
  test "dashboard requires authentication" do
    get root_url
    assert_redirected_to new_session_url
  end

  test "authenticated user reaches the admin pages" do
    sign_in_as users(:one)

    get root_url
    assert_response :success
    assert_select "h1", "Dashboard"

    get inverters_url
    assert_response :success

    get mqtt_config_url
    assert_response :success

    get api_tokens_url
    assert_response :success

    get tariff_url
    assert_response :success
  end

  test "inverter page renders every aggregate period" do
    sign_in_as users(:one)

    %w[day month year lifetime].each do |period|
      get inverter_url(inverters(:garage), period: period, date: "2026-06-09")
      assert_response :success
    end
  end

  test "configured tariff surfaces cost figures on the month breakdown" do
    sign_in_as users(:one)

    get inverter_url(inverters(:garage), period: "month", date: "2026-06-09")
    assert_response :success
    assert_includes response.body, "Import cost"
    assert_includes response.body, "Net"
  end

  test "changing the selected day changes the rendered totals" do
    sign_in_as users(:one)

    get inverter_url(inverters(:garage), period: "day", date: "2026-06-08")
    assert_includes response.body, "20.0 kWh" # Jun 8 generation

    get inverter_url(inverters(:garage), period: "day", date: "2026-06-09")
    assert_includes response.body, "12.0 kWh" # Jun 9 generation
  end

  test "dashboard shows a site-wide energy & cost summary" do
    sign_in_as users(:one)

    get root_url(period: "month", date: "2026-06-09")
    assert_response :success
    assert_includes response.body, "Energy &amp; costs"
    assert_includes response.body, "dashboard_aggregates"
    assert_includes response.body, "Import cost" # tariff configured in fixtures
  end

  test "a user can edit the tariff" do
    sign_in_as users(:one)

    patch tariff_url, params: { tariff: { import_rate: "0.42", export_rate: "0.08", currency: "€" } }
    assert_redirected_to tariff_url
    assert_equal 0.42, Tariff.instance.import_rate.to_f
    assert_equal "€", Tariff.instance.currency
  end

  test "a signed-in user can add an inverter and generate a token" do
    sign_in_as users(:one)

    assert_difference -> { Inverter.count }, 1 do
      post inverters_url, params: { inverter: { name: "Loft", mqtt_topic: "ghrian/inverter/99" } }
    end
    assert_redirected_to inverters_url

    assert_difference -> { ApiToken.count }, 1 do
      post api_tokens_url, params: { api_token: { name: "macOS app" } }
    end
    assert_redirected_to api_tokens_url
  end

  test "the first account can register, after which registration closes" do
    User.destroy_all

    get new_registration_url
    assert_response :success

    assert_difference -> { User.count }, 1 do
      post registration_url, params: { user: {
        email_address: "admin@example.com", password: "secret123", password_confirmation: "secret123"
      } }
    end
    assert_redirected_to root_url

    # Now that an account exists, registration is closed.
    get new_registration_url
    assert_redirected_to new_session_url
  end

  test "registration is closed once an account exists" do
    # Fixtures already include users.
    get new_registration_url
    assert_redirected_to new_session_url

    assert_no_difference -> { User.count } do
      post registration_url, params: { user: {
        email_address: "intruder@example.com", password: "secret123", password_confirmation: "secret123"
      } }
    end
    assert_redirected_to new_session_url
  end

  test "an admin can create and remove user accounts" do
    sign_in_as users(:one)

    get users_url
    assert_response :success

    assert_difference -> { User.count }, 1 do
      post users_url, params: { user: {
        email_address: "teammate@example.com", password: "secret123", password_confirmation: "secret123"
      } }
    end
    assert_redirected_to users_url

    teammate = User.find_by(email_address: "teammate@example.com")
    assert_difference -> { User.count }, -1 do
      delete user_url(teammate)
    end
    assert_redirected_to users_url
  end

  test "a user cannot remove their own account" do
    sign_in_as users(:one)

    assert_no_difference -> { User.count } do
      delete user_url(users(:one))
    end
    assert_redirected_to users_url
  end
end
