class MakeReadingsUniquePerTimestamp < ActiveRecord::Migration[8.1]
  # QoS-1 delivery is at-least-once, so the broker can redeliver a data message.
  # Every message carries a unique (inverter, timestamp), so promoting the existing
  # lookup index to UNIQUE turns a redelivery into an insert conflict the ingest
  # path swallows — instead of a duplicate time-series row. The index still serves
  # the range/grouping queries it did before.
  def up
    remove_index :readings, name: "index_readings_on_inverter_id_and_recorded_at"
    add_index :readings, [ :inverter_id, :recorded_at ], unique: true,
      name: "index_readings_on_inverter_id_and_recorded_at"
  end

  def down
    remove_index :readings, name: "index_readings_on_inverter_id_and_recorded_at"
    add_index :readings, [ :inverter_id, :recorded_at ],
      name: "index_readings_on_inverter_id_and_recorded_at"
  end
end
