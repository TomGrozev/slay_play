defmodule SlayPlayWeb.AdminLive.Songs do
  use SlayPlayWeb, :live_view

  alias Phoenix.LiveView.JS
  alias SlayPlay.{MP3Stat, Player}
  alias SlayPlayWeb.LayoutComponent
  alias SlayPlayWeb.AdminLive.{SongRowComponent, SongUploadFormComponent}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mt-4 flex justify-end items-center">
      <.button id="upload-btn" primary patch={Routes.admin_songs_path(@socket, :new)}>
        <.icon name={:arrow_up_tray} /><span class="ml-2">Upload Songs</span>
      </.button>
    </div>
    <div id="dialogs" phx-update="append">
      <%= for song <- @songs, id = "delete-modal-#{song.id}" do %>
        <.modal
          id={id}
          on_confirm={
            JS.push("delete", value: %{id: song.id})
            |> hide_modal(id)
            |> focus_closest("#song-#{song.id}")
            |> hide("#song-#{song.id}")
          }
          on_cancel={focus("##{id}", "#delete-song-#{song.id}")}
        >
          Are you sure you want to delete "<%= song.title %>"?
          <:cancel>Cancel</:cancel>
          <:confirm>Delete</:confirm>
        </.modal>
      <% end %>
    </div>
    <.live_table
      id="songs"
      module={SongRowComponent}
      rows={@songs}
      row_id={fn song -> "song-#{song.id}" end}
    >
      <:col :let={%{song: song}} label="Title"><%= song.title %></:col>
      <:col :let={%{song: song}} label="Artist"><%= song.artist %></:col>
      <:col :let={%{song: song}} label="Duration"><%= MP3Stat.to_mmss(song.duration) %></:col>
      <:col :let={%{song: song}} label="">
        <.link
          id={"delete-song-#{song.id}"}
          phx-click={show_modal("delete-modal-#{song.id}")}
          class="inline-flex items-center px-3 py-2 text-sm leading-4 font-medium"
        >
          <.icon name={:trash} class="-ml-0.5 mr-2 h-4 w-4" /> Delete
        </.link>
      </:col>
    </.live_table>
    """
  end

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Player.subscribe()
    end

    active_song_id =
      if song = Player.get_current_active_song() do
        SongRowComponent.send_status(song.id, song.status)

        song.id
      end

    socket =
      socket
      |> assign(:active_song_id, active_song_id)
      |> list_songs()
      |> assign_presences()

    {:ok, socket, temporary_assigns: [songs: [], presences: %{}]}
  end

  def handle_params(params, _url, socket) do
    LayoutComponent.hide_modal()
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing songs")
    |> assign(:song, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Add Music")
    |> assign(:song, %Player.Song{})
    |> show_upload_modal()
  end

  def handle_event("play_or_pause", %{"id" => id}, socket) do
    song = Player.get_song!(id)

    # check for if can control playback??
    cond do
      socket.assigns.active_song_id == id and Player.playing?(song) ->
        Player.pause_song(song)

      true ->
        Player.play_song(id)
    end

    {:noreply, socket}
  end

  def handle_info({Player, %Player.Events.Play{song: song}}, socket) do
    {:noreply, play_song(socket, song)}
  end

  def handle_info({Player, %Player.Events.Pause{song: song}}, socket) do
    {:noreply, pause_song(socket, song.id)}
  end

  def handle_info({Player, %Player.Events.SongsImported{songs: songs}}, socket) do
    {:noreply, update(socket, :songs, &(&1 ++ songs))}
  end

  def handle_info({Player, _}, socket), do: {:noreply, socket}

  defp stop_song(socket, song_id) do
    SongRowComponent.send_status(song_id, :stopped)

    if socket.assigns.active_song_id == song_id do
      assign(socket, :active_song_id, nil)
    else
      socket
    end
  end

  defp pause_song(socket, song_id) do
    SongRowComponent.send_status(song_id, :paused)
    socket
  end

  defp play_song(socket, %Player.Song{} = song) do
    %{active_song_id: active_song_id} = socket.assigns

    cond do
      active_song_id == song.id ->
        SongRowComponent.send_status(song.id, :playing)
        socket

      active_song_id ->
        SongRowComponent.send_status(song.id, :playing)

        socket
        |> stop_song(active_song_id)
        |> assign(active_song_id: song.id)

      true ->
        SongRowComponent.send_status(song.id, :playing)
        assign(socket, active_song_id: song.id)
    end
  end

  defp show_upload_modal(socket) do
    LayoutComponent.show_modal(SongUploadFormComponent, %{
      id: :new,
      confirm: {"Save", type: "submit", form: "song-form"},
      patch: SlayPlayWeb.Router.Helpers.admin_songs_path(socket, :index),
      song: socket.assigns.song,
      title: socket.assigns.page_title
    })

    socket
  end

  defp list_songs(socket) do
    assign(socket, songs: Player.list_songs(50))
  end

  defp assign_presences(socket) do
    socket = assign(socket, presences_count: 0, presences: %{}, presence_ids: %{})

    socket
  end
end
