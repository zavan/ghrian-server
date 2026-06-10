module ApplicationHelper
  # Registration is open only until the first account exists (bootstrap).
  def registration_open?
    !User.exists?
  end

  # Lucide icon matching an inverter status.
  STATUS_ICONS = { "online" => "wifi", "offline" => "wifi-off", "unknown" => "circle-help" }.freeze

  # Status pill with its matching icon (online / offline / unknown).
  def status_badge(status)
    status = status.to_s
    tag.span(class: "badge badge-#{status} inline-flex items-center gap-1") do
      safe_join([ lucide_icon(STATUS_ICONS.fetch(status, "circle-help"), class: "size-3"), status ])
    end
  end

  # Lucide icon for a flash type (success vs error).
  def flash_icon(type)
    lucide_icon(type.to_sym == :notice ? "check-circle" : "circle-alert", class: "size-5 shrink-0")
  end

  # Tailwind classes for a flash message by type.
  def flash_classes(type)
    case type.to_sym
    when :notice
      "border-green-500 bg-green-500/15 text-green-700 dark:text-green-200"
    else
      "border-red-500 bg-red-500/15 text-red-700 dark:text-red-200"
    end
  end

  # Lucide icon names for each power-flow node. The partials call power_icon so
  # they stay readable; everywhere else uses lucide_icon directly.
  POWER_ICONS = {
    pv: "sun",
    grid: "utility-pole",
    battery: "battery-charging",
    load: "house",
    inverter: "cpu"
  }.freeze

  def power_icon(key, size: 22)
    lucide_icon(POWER_ICONS.fetch(key.to_sym), class: "shrink-0", size: size)
  end
end
