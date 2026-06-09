require "test_helper"

class EnergySummaryTest < ActiveSupport::TestCase
  # Fixtures: garage has daily summaries Jun 8 (gen 20) and Jun 9 (gen 12).
  def garage_summary(period, date)
    EnergySummary.new(inverters(:garage).daily_summaries, period: period, date: date)
  end

  test "day range is a single day and totals reflect that date" do
    s = garage_summary("day", Date.new(2026, 6, 8))
    assert_equal Date.new(2026, 6, 8)..Date.new(2026, 6, 8), s.range
    assert_in_delta 20.0, s.totals.generation, 0.001

    other = garage_summary("day", Date.new(2026, 6, 9))
    assert_in_delta 12.0, other.totals.generation, 0.001
  end

  test "month sums the whole month" do
    assert_in_delta 32.0, garage_summary("month", Date.new(2026, 6, 15)).totals.generation, 0.001
  end

  test "month breakdown is per-day generation columns" do
    breakdown = garage_summary("month", Date.new(2026, 6, 9)).breakdown
    assert_includes breakdown, [ "8", 20.0 ]
    assert_includes breakdown, [ "9", 12.0 ]
  end

  test "year breakdown has twelve month columns" do
    assert_equal 12, garage_summary("year", Date.new(2026, 6, 9)).breakdown.size
  end

  test "navigation labels and steps per period" do
    s = garage_summary("day", Date.new(2026, 6, 9))
    assert_equal "09/06/2026", s.label
    assert_equal Date.new(2026, 6, 8), s.prev_date
    assert_equal Date.new(2026, 6, 10), s.next_date
    assert s.navigable?

    assert_not garage_summary("lifetime", Date.current).navigable?
    assert_equal "All time", garage_summary("lifetime", Date.current).label
  end

  test "an unknown period falls back to day" do
    assert_equal "day", EnergySummary.new(DailySummary.all, period: "bogus", date: nil).period
  end

  test "a site-wide scope sums across inverters" do
    s = EnergySummary.new(DailySummary.all, period: "month", date: Date.new(2026, 6, 9))
    assert_in_delta 32.0, s.totals.generation, 0.001
  end
end
