json.id inverter.id
json.name inverter.name
json.device_model inverter.device_model
json.mqtt_topic inverter.mqtt_topic
json.serial_number inverter.serial_number
json.status inverter.status
json.last_reading_at inverter.last_reading_at
json.last_seen_at inverter.last_seen_at
json.latest_values inverter.latest_values || {}

# Display-ready overview computed by Inverter::Snapshot, so clients don't have to
# reimplement the meter-vs-port grid fallback, battery charge/discharge direction,
# or sign conventions. Raw `latest_values` is still above for anything bespoke.
snapshot = inverter.snapshot
json.snapshot do
  json.flows do
    snapshot.flows.each do |flow|
      json.set! flow.key do
        json.key flow.key
        json.label flow.label
        json.watts flow.watts
        json.kw flow.kw
        json.direction flow.direction # "in" | "out" | "idle" (relative to the inverter)
      end
    end
  end

  json.battery_soc snapshot.soc
  json.temperature snapshot.temperature

  # Today's cumulative energy (kWh), reset by the device at midnight.
  json.today do
    json.set! "yield", snapshot.daily_yield
    json.charge snapshot.daily_charge
    json.discharge snapshot.daily_discharge
    json.to_grid snapshot.to_grid_energy
    json.from_grid snapshot.from_grid_energy
    json.consumption snapshot.consumption_energy
  end
end
