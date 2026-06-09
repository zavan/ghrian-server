module ApplicationHelper
  # Registration is open only until the first account exists (bootstrap).
  def registration_open?
    !User.exists?
  end

  # Tailwind classes for a flash message by type.
  def flash_classes(type)
    case type.to_sym
    when :notice
      "border-green-500 bg-green-500/15 text-green-200"
    else
      "border-red-500 bg-red-500/15 text-red-200"
    end
  end

  # Inline (currentColor) icon for a power-flow node. Kept here so the partial
  # markup stays readable.
  POWER_ICONS = {
    pv: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/>',
    grid: '<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/>',
    battery: '<rect x="2" y="7" width="16" height="10" rx="2"/><path d="M22 11v2"/><path d="M10 9l-2 6h4l-2 4"/>',
    load: '<path d="M3 11.5 12 4l9 7.5"/><path d="M5 10v10h14V10"/>',
    inverter: '<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M13 7l-3 5h4l-3 5"/>'
  }.freeze

  def power_icon(key, size: 22)
    paths = POWER_ICONS.fetch(key.to_sym)
    content_tag(:svg, paths.html_safe,
      class: "shrink-0", width: size, height: size, viewBox: "0 0 24 24",
      fill: "none", stroke: "currentColor", "stroke-width": "1.8",
      "stroke-linecap": "round", "stroke-linejoin": "round")
  end
end
