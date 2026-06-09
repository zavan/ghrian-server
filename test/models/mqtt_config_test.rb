require "test_helper"

class MqttConfigTest < ActiveSupport::TestCase
  test "instance returns the singleton row" do
    assert_equal MqttConfig.first, MqttConfig.instance
  end

  test "instance seeds connection settings from the environment on first create" do
    MqttConfig.delete_all
    ENV["MQTT_HOST"] = "broker.internal"
    ENV["MQTT_BASE_TOPIC"] = "solarfarm"

    config = MqttConfig.instance
    assert_equal "broker.internal", config.host
    assert_equal "solarfarm", config.base_topic
  ensure
    ENV.delete("MQTT_HOST")
    ENV.delete("MQTT_BASE_TOPIC")
  end

  test "instance does not let the environment override an existing config" do
    existing_host = mqtt_configs(:primary).host # an admin-managed row already exists
    ENV["MQTT_HOST"] = "broker.internal"

    assert_equal existing_host, MqttConfig.instance.host
  ensure
    ENV.delete("MQTT_HOST")
  end

  test "subscribe_filter is the base topic wildcard" do
    assert_equal "ghrian/#", mqtt_configs(:primary).subscribe_filter
  end

  test "subscribe_filter tolerates a trailing slash" do
    config = mqtt_configs(:primary)
    config.base_topic = "ghrian/"
    assert_equal "ghrian/#", config.subscribe_filter
  end

  test "broker_url reflects TLS" do
    config = mqtt_configs(:primary)
    assert_equal "mqtt://localhost:1883", config.broker_url
    config.use_tls = true
    assert_equal "mqtts://localhost:1883", config.broker_url
  end

  test "client_identifier falls back to a default" do
    assert_equal "ghrian-server", mqtt_configs(:primary).client_identifier
  end

  test "password is encrypted at rest" do
    config = mqtt_configs(:primary)
    config.update!(password: "s3cret")
    assert_equal "s3cret", config.reload.password

    raw = MqttConfig.connection.select_value("SELECT password FROM mqtt_configs WHERE id = #{config.id}")
    refute_equal "s3cret", raw
  end

  test "requires a valid port" do
    config = mqtt_configs(:primary)
    config.port = 0
    assert_not config.valid?
  end
end
