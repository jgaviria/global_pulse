defmodule GlobalPulseWeb.Layouts do
  use GlobalPulseWeb, :html

  embed_templates "layouts/*"
  
  def format_time(nil), do: "Never"
  def format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S UTC")
  end
end