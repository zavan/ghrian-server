# One decoded MQTT message from an inverter. `data` is the agent's self-describing
# `values` map verbatim: { "<key>" => { "value" => ..., "unit" => ..., "label" => ... } }.
# Values may be a number, a string, or an array of strings (bitfield "<name>_active"),
# so accessors stay defensive and never assume a fixed schema.
class Reading < ApplicationRecord
  belongs_to :inverter

  # Force JSON (de)serialization regardless of adapter handling of the column type.
  attribute :data, :json

  scope :chronological, -> { order(:recorded_at) }
  scope :since, ->(time) { where(recorded_at: time..) if time }
  scope :through, ->(time) { where(recorded_at: ..time) if time }

  # Raw value for a metric key, e.g. value_for("battery_soc") => 87.
  def value_for(key)
    data&.dig(key.to_s, "value")
  end

  # Unit string for a metric key, e.g. unit_for("active_power") => "W".
  def unit_for(key)
    data&.dig(key.to_s, "unit")
  end
end
