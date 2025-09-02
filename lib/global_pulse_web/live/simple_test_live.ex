defmodule GlobalPulseWeb.SimpleTestLive do
  use GlobalPulseWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Simple Test")
     |> assign(:message, "Hello World")
    }
  end

  def render(assigns) do
    ~H"""
    <div class="p-8">
      <h1 class="text-2xl font-bold">Simple Test</h1>
      <p><%= @message %></p>
    </div>
    """
  end
end