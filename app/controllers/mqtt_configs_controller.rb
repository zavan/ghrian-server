# Edits the single shared broker connection. Saving bumps `updated_at`, which the
# running listener notices and reconnects on (best-effort; a restart is always safe).
class MqttConfigsController < ApplicationController
  before_action :set_mqtt_config

  def show
  end

  def edit
  end

  def update
    if @mqtt_config.update(mqtt_config_params)
      redirect_to mqtt_config_path, notice: "MQTT connection saved. The listener will reconnect."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_mqtt_config
      @mqtt_config = MqttConfig.instance
    end

    def mqtt_config_params
      permitted = params.require(:mqtt_config).permit(:host, :port, :username, :password, :client_id, :base_topic, :use_tls)
      # Leave the stored (encrypted) password untouched when the field is left blank.
      permitted.delete(:password) if permitted[:password].blank?
      permitted
    end
end
