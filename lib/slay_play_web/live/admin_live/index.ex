defmodule SlayPlayWeb.AdminLive.Index do
  use SlayPlayWeb, :live_view

  alias SlayPlay.Player
  alias SlayPlayWeb.AdminLive.StationRowComponent

  @impl true
  def render(assigns) do
    ~H"""
    <.live_table
      id="stations"
      module={StationRowComponent}
      rows={@stations}
      row_id={fn station -> "station-#{station.id}" end}
    >
      <:col :let={%{station: station}} label="Name"><%= station.name %></:col>
      <:col :let={%{station: station}} label="Transition Seconds"><%= station.transition_time_s %></:col>
    </.live_table>

    <div class="flex items-center justify-space-around mt-4 mr-4 float-right">
      <.button id="link-slides" primary patch={Routes.admin_slides_path(@socket, :index)}>Manage Slides</.button>
      <.button id="link-songs" primary patch={Routes.admin_songs_path(@socket, :index)}>Manage Songs</.button>
    </div>
    """
  end

  def mount(_params, _assigns, socket) do
    {:ok, assign(socket, :stations, list_stations())}
  end

  defp list_stations do
    Player.list_stations(50)
  end
end
