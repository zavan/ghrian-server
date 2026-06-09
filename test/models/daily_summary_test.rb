require "test_helper"

class DailySummaryTest < ActiveSupport::TestCase
  test "totals sums the kWh columns over a relation" do
    totals = inverters(:garage).daily_summaries.totals
    assert_in_delta 32.0, totals[:generation_kwh], 0.001
    assert_in_delta 22.0, totals[:feed_in_kwh], 0.001
    assert_in_delta 2.5, totals[:import_kwh], 0.001
  end

  test "between scopes by date range" do
    june8 = Date.new(2026, 6, 8)
    totals = inverters(:garage).daily_summaries.between(june8..june8).totals
    assert_in_delta 20.0, totals[:generation_kwh], 0.001
  end
end
