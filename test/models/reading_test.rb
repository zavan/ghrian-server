require "test_helper"

class ReadingTest < ActiveSupport::TestCase
  test "value_for and unit_for read the values map defensively" do
    reading = readings(:garage_recent)
    assert_equal 80, reading.value_for("battery_soc")
    assert_equal "%", reading.unit_for("battery_soc")
    assert_nil reading.value_for("missing")
    assert_nil reading.unit_for("missing")
  end

  test "chronological orders by recorded_at" do
    assert_equal [ readings(:garage_old), readings(:garage_recent) ],
      inverters(:garage).readings.chronological.to_a
  end

  test "since filters by time" do
    recent = inverters(:garage).readings.since(90.minutes.ago).chronological
    assert_equal [ readings(:garage_recent) ], recent.to_a
  end
end
