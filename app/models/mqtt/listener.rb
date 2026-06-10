# Long-running MQTT subscriber. A PORO (no service layer) that lives next to the
# MqttConfig model. It connects to the broker described by MqttConfig.instance,
# subscribes to the one wildcard covering every inverter topic, and hands each
# message to Inverter.ingest. Runs in its own process (bin/mqtt-listener), separate
# from Puma.
#
# Resilience:
# - Reconnects with a fixed backoff on any connection error.
# - A monitor thread disconnects the client when the admin edits the broker config
#   (so changes apply without a manual restart) or on SIGINT/SIGTERM.
module Mqtt
  class Listener
    RECONNECT_DELAY = 5 # seconds
    CONFIG_POLL = 2     # seconds between config-change / shutdown checks

    def initialize(logger: Rails.logger)
      @logger = logger
      @stopping = false
    end

    def run
      trap_signals
      @logger.info("[mqtt] listener starting")
      until @stopping
        begin
          listen(MqttConfig.instance)
        rescue => e
          break if @stopping
          @logger.error("[mqtt] #{e.class}: #{e.message}; reconnecting in #{RECONNECT_DELAY}s")
          interruptible_sleep(RECONNECT_DELAY)
        end
      end
      @logger.info("[mqtt] listener stopped")
    end

    private
      def listen(config)
        @logger.info("[mqtt] connecting to #{config.broker_url}, subscribing #{config.subscribe_filter}")
        client = MQTT::Client.connect(connect_options(config))
        monitor = start_monitor(client, config)
        begin
          # QoS 1: live availability transitions (online/offline) must not be dropped.
          client.subscribe(config.subscribe_filter => 1)
          @logger.info("[mqtt] connected; waiting for messages")
          client.get { |topic, message| dispatch(topic, message) }
        rescue MQTT::Exception, IOError, SystemCallError
          # A disconnect from the monitor thread (config change / shutdown) unblocks
          # `get` with one of these. Re-raise only if it was a genuine fault.
          raise unless @stopping || config_stale?(config)
          @logger.info("[mqtt] broker config changed; reconnecting") if config_stale?(config)
        ensure
          monitor.kill
          safe_disconnect(client)
        end
      end

      def dispatch(topic, message)
        Inverter.ingest(topic: topic, payload: message)
      rescue => e
        @logger.error("[mqtt] ingest failed for #{topic}: #{e.class}: #{e.message}")
      end

      def connect_options(config)
        {
          host: config.host,
          port: config.port,
          client_id: config.client_identifier,
          username: config.username.presence,
          password: config.password.presence,
          ssl: config.use_tls
        }.compact
      end

      # Watches for shutdown or a broker-config edit and disconnects the client to
      # break out of the blocking `get`.
      def start_monitor(client, config)
        Thread.new do
          loop do
            sleep CONFIG_POLL
            if @stopping || config_stale?(config)
              safe_disconnect(client)
              break
            end
          end
        end
      end

      def config_stale?(config)
        MqttConfig.instance.updated_at != config.updated_at
      end

      def safe_disconnect(client)
        client&.disconnect
      rescue StandardError
        nil
      end

      def interruptible_sleep(seconds)
        (seconds * 2).times do
          break if @stopping
          sleep 0.5
        end
      end

      def trap_signals
        %w[INT TERM].each { |sig| Signal.trap(sig) { @stopping = true } }
      end
  end
end
