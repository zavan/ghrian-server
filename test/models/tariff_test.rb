require "test_helper"

class TariffTest < ActiveSupport::TestCase
  test "instance returns the singleton row" do
    assert_equal Tariff.first, Tariff.instance
  end

  test "cost and earnings multiply kWh by the rates" do
    tariff = tariffs(:default) # import 0.30, export 0.10
    assert_in_delta 3.0, tariff.cost(10), 0.001
    assert_in_delta 1.0, tariff.earnings(10), 0.001
    assert_equal 0.0, tariff.cost(nil)
  end

  test "format renders currency with sign" do
    tariff = tariffs(:default)
    assert_equal "$1.45", tariff.format(1.45)
    assert_equal "-$1.2", tariff.format(-1.2)
  end

  test "configured? is true when a rate is set" do
    assert tariffs(:default).configured?
    assert_not Tariff.new(import_rate: 0, export_rate: 0, currency: "$").configured?
  end

  test "rates cannot be negative" do
    assert_not Tariff.new(import_rate: -1, export_rate: 0, currency: "$").valid?
  end
end
