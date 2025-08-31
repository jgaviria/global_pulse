defmodule GlobalPulse.StreamSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_stream(module, args) do
    spec = {module, args}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_stream(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  def list_streams do
    DynamicSupervisor.which_children(__MODULE__)
  end
end