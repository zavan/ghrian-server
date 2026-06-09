# Singleton broker settings for the MQTT connection the server subscribes to.
#
# There is exactly one MqttConfig row for the whole installation (shared install);
# use MqttConfig.instance to load-or-build it. The password is encrypted at rest.
class MqttConfig < ApplicationRecord
  encrypts :password

  validates :host, presence: true
  validates :port, presence: true, numericality: { only_integer: true, in: 1..65_535 }
  validates :base_topic, presence: true

  # The single shared configuration row, created with defaults on first access.
  def self.instance
    first_or_create!
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
