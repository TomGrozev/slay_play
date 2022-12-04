defmodule SlayPlay.SlideClock do
  @moduledoc """
  Changes slides for each station on an interval
  """
  use GenServer

  alias SlayPlay.Player

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    stations = Player.list_stations()

    {:ok, schedule_transitions(stations)}
  end

  @impl true
  def handle_info({:transition, %Player.Station{} = station}, _state) do
    Player.set_next_slide(station)
    {:noreply, schedule_transition(station)}
  end

  defp schedule_transitions(stations) do
    for station <- stations do
      schedule_transition(station)
    end

    stations
  end

  defp schedule_transition(%Player.Station{transition_time_s: interval} = station) do
    Process.send_after(self(), {:transition, station}, 1000 * interval)
  end
end
