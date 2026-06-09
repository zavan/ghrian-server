require "test_helper"

class InverterTest < ActiveSupport::TestCase
  SAMPLE = {
    "timestamp" => "2026-06-04T12:34:56.789Z",
    "device_model" => "solis_s5-eh1p5k-l",
    "values" => {
      "active_power" => { "value" => -1234, "unit" => "W", "label" => "Active Power" },
      "battery_soc" => { "value" => 87, "unit" => "%", "label" => "Battery Capacity SOC" },
      "operating_status_active" => { "value" => [ "Normal operation" ], "unit" => "", "label" => "Operating Status (active bits)" }
    }
  }.freeze

  test "ingest data message creates a reading and refreshes the snapshot" do
    inverter = inverters(:shed) # starts offline, no readings

    reading = Inverter.ingest(topic: "ghrian/inverter/02", payload: SAMPLE.to_json)

    assert_not_nil reading
    assert_equal inverter, reading.inverter
    assert_equal 87, reading.value_for("battery_soc")
    assert_equal "W", reading.unit_for("active_power")

    inverter.reload
    assert_equal "online", inverter.status
    assert_equal "solis_s5-eh1p5k-l", inverter.device_model
    assert_equal 87, inverter.current_value("battery_soc")
    assert_equal(-1234, inverter.current_value("active_power"))
    assert_equal [ "Normal operation" ], inverter.current_value("operating_status_active")
    assert_equal Time.zone.parse("2026-06-04T12:34:56.789Z").to_i, inverter.last_reading_at.to_i
  end

  test "ingest accepts an already-decoded hash payload" do
    reading = Inverter.ingest(topic: "ghrian/inverter/02",
      payload: { "values" => { "battery_soc" => { "value" => 50 } } })
    assert_equal 50, reading.value_for("battery_soc")
  end

  test "availability message flips status without creating a reading" do
    inverter = inverters(:garage)

    assert_no_difference -> { inverter.readings.count } do
      Inverter.ingest(topic: "ghrian/inverter/01/availability", payload: "offline")
    end
    assert_equal "offline", inverter.reload.status

    Inverter.ingest(topic: "ghrian/inverter/01/availability", payload: "ONLINE\n")
    assert_equal "online", inverter.reload.status
  end

  test "unknown topics are ignored" do
    assert_nil Inverter.ingest(topic: "ghrian/unknown", payload: "{}")
    assert_nil Inverter.ingest(topic: "ghrian/unknown/availability", payload: "online")
  end

  test "invalid JSON is tolerated" do
    assert_nil inverters(:garage).record_reading("not json{")
  end

  test "availability_topic derives from mqtt_topic" do
    assert_equal "ghrian/inverter/01/availability", inverters(:garage).availability_topic
  end

  test "requires name and a unique mqtt_topic" do
    assert_not Inverter.new(mqtt_topic: "x").valid?
    dup = Inverter.new(name: "Dup", mqtt_topic: inverters(:garage).mqtt_topic)
    assert_not dup.valid?
  end

  test "recording readings rolls today_* counters into a daily summary (running max)" do
    inverter = inverters(:shed)
    day = "2026-06-20"
    energy = ->(gen, feed) do
      { "timestamp" => "#{day}T#{format('%02d', gen)}:00:00Z", "values" => {
        "today_energy_generation" => { "value" => gen },
        "today_energy_fed_into_grid" => { "value" => feed }
      } }.to_json
    end

    assert_difference -> { inverter.daily_summaries.count }, 1 do
      inverter.record_reading(energy.call(10, 6))
      inverter.record_reading(energy.call(18, 11)) # later, higher
    end

    summary = inverter.daily_summaries.find_by(date: Date.parse(day))
    assert_in_delta 18.0, summary.generation_kwh, 0.001 # max, not sum
    assert_in_delta 11.0, summary.feed_in_kwh, 0.001
  end

  test "totals_between sums daily summaries and derives self-consumption" do
    totals = inverters(:garage).totals_between(Date.new(2026, 6, 1)..Date.new(2026, 6, 30))
    assert_in_delta 32.0, totals.generation, 0.001
    assert_in_delta 22.0, totals.feed_in, 0.001
    assert_in_delta 10.0, totals.self_consumption, 0.001 # 32 generated - 22 exported
  end

  test "energy totals compute money against a tariff" do
    totals = inverters(:garage).totals_between(Date.new(2026, 6, 1)..Date.new(2026, 6, 30))
    tariff = tariffs(:default) # import 0.30, export 0.10
    assert_in_delta 0.75, totals.import_cost(tariff), 0.001  # 2.5 kWh * 0.30
    assert_in_delta 2.20, totals.export_earnings(tariff), 0.001 # 22 kWh * 0.10
    assert_in_delta 1.45, totals.net(tariff), 0.001
    assert_in_delta 3.00, totals.savings(tariff), 0.001 # 10 kWh self-consumed * 0.30
  end
end
