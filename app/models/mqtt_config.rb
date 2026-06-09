# Singleton broker settings for the MQTT connection the server subscribes to.
#
# There is exactly one MqttConfig row for the whole installation (shared install);
# use MqttConfig.instance to load-or-build it. The password is encrypted at rest.
class MqttConfig < ApplicationRecord
  encrypts :password

  validates :host, presence: true
  validates :port, presence: true, numericality: { only_integer: true, in: 1..65_535 }
  validates :base_topic, presence: true

  # The single shared configuration row, created on first access. On creation the
  # connection settings are seeded from the environment when present (MQTT_HOST,
  # MQTT_PORT, MQTT_BASE_TOPIC, MQTT_USERNAME, MQTT_PASSWORD, MQTT_USE_TLS), so a
  # fresh container deploy can connect with no UI step. Seeding happens only on
  # create — once the row exists, the admin UI is the source of truth.
  def self.instance
    first_or_create! { |config| config.apply_env_defaults }
  end

  def apply_env_defaults
    self.host = ENV["MQTT_HOST"] if ENV["MQTT_HOST"].present?
    self.port = ENV["MQTT_PORT"] if ENV["MQTT_PORT"].present?
    self.base_topic = ENV["MQTT_BASE_TOPIC"] if ENV["MQTT_BASE_TOPIC"].present?
    self.username = ENV["MQTT_USERNAME"] if ENV["MQTT_USERNAME"].present?
    self.password = ENV["MQTT_PASSWORD"] if ENV["MQTT_PASSWORD"].present?
    self.use_tls = ActiveModel::Type::Boolean.new.cast(ENV["MQTT_USE_TLS"]) if ENV["MQTT_USE_TLS"].present?
  end

  # Wildcard the listener subscribes to: every topic under the base (data +
  # the agent's retained "<topic>/availability"). One subscription means new
  # inverters are matched live without a reconnect.
  def subscribe_filter
    "#{base_topic.sub(%r{/+\z}, "")}/#"
  end

  # Broker URL, e.g. "mqtt://localhost:1883" ("mqtts" when TLS is enabled).
  def broker_url
    "#{use_tls ? "mqtts" : "mqtt"}://#{host}:#{port}"
  end

  def client_identifier
    client_id.presence || "ghrian-server"
  end
end
