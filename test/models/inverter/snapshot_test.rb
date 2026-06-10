require "test_helper"

class Inverter::SnapshotTest < ActiveSupport::TestCase
  def snapshot(values)
    Inverter::Snapshot.new(values)
  end

  def metric(value)
    { "value" => value }
  end

  test "power flow exposes pv/grid/battery/load with hub-relative direction" do
    s = snapshot(
      "total_dc_output_power" => metric(1194),
      "inverter_ac_grid_port_power" => metric(872),   # + => exporting
      "battery_power" => metric(0),
      "household_load_power" => metric(322)
    )

    assert_equal :in, s.pv.direction
    assert_equal 1.194, s.pv.kw
    assert_equal "0.872 kW", s.grid.display
    assert_equal :out, s.grid.direction          # exporting
    assert_equal "Exporting", s.grid_state
    assert_equal :out, s.load.direction
    assert_equal :idle, s.battery.direction       # 0 W
    assert_equal "Standby", s.battery_state
  end

  test "grid importing flips direction and label" do
    s = snapshot("inverter_ac_grid_port_power" => metric(-500))
    assert_equal :in, s.grid.direction
    assert_equal "Grid (Importing)", s.grid.label
    assert_equal "Importing", s.grid_state
  end

  test "grid prefers the meter reading over the inverter grid-port power" do
    # On battery at night: the inverter feeds the house through its grid port
    # (port ≈ load), but the external meter shows ~0 net grid. Trust the meter.
    s = snapshot(
      "meter_active_power" => metric(0),
      "inverter_ac_grid_port_power" => metric(256),
      "household_load_power" => metric(256)
    )
    assert_equal :idle, s.grid.direction
    assert_equal "0.0 kW", s.grid.display
    assert_equal "Idle", s.grid_state
  end

  test "grid falls back to the inverter grid-port power when no meter is reported" do
    s = snapshot("inverter_ac_grid_port_power" => metric(-500))
    assert_equal(-0.5, s.grid.watts / 1000.0)
    assert_equal :in, s.grid.direction
  end

  test "battery charging vs discharging from current_direction" do
    charging = snapshot("battery_power" => metric(800), "battery_current_direction" => metric(0))
    assert_equal :out, charging.battery.direction
    assert_equal "Charging", charging.battery_state

    discharging = snapshot("battery_power" => metric(800), "battery_current_direction" => metric(1))
    assert_equal :in, discharging.battery.direction
    assert_equal "Discharging", discharging.battery_state
  end

  test "battery direction falls back to power sign without a direction metric" do
    assert_equal :out, snapshot("battery_power" => metric(500)).battery.direction
    assert_equal :in, snapshot("battery_power" => metric(-500)).battery.direction
  end

  test "self-consumption split derives from generation and grid export" do
    s = snapshot(
      "today_energy_generation" => metric(32.1),
      "today_energy_fed_into_grid" => metric(22.98)
    )
    assert_in_delta 9.12, s.to_consumption_kwh, 0.001
    assert_equal 28, s.consumption_pct
    assert_equal 72, s.grid_pct
  end

  test "missing metrics render as dashes and nil" do
    s = snapshot({})
    assert_equal "—", s.pv.display
    assert_nil s.soc
    assert_nil s.consumption_pct
    assert_equal "Standby", s.battery_state
  end
end
