defmodule SlayPlayWeb.PlayerLive do
  use SlayPlayWeb, {:live_view, container: {:div, [class: "fixed w-screen bottom-0 left-0"]}}

  alias Phoenix.LiveView.JS
  alias SlayPlay.Player
  alias SlayPlayWeb.Presence

  def render(assigns) do
    ~H"""
    <!-- player -->
    <div id="audio-player" phx-hook="AudioPlayer" class="w-full" role="region" aria-label="Player">
      <div id="audio-ignore" phx-update="ignore">
        <audio></audio>
      </div>
      <button phx-click={toggle_player()} class="absolute -mt-6 px-1 bg-gray-200 rounded-tl-lg rounded-tr-lg right-4">
        <.icon name={:chevron_up} />
      </button>
      <div id="audio-controls" class="relative hidden">
        <div class="bg-white dark:bg-gray-800 p-4">
          <div class="flex items-center space-x-3.5 sm:space-x-5 lg:space-x-3.5 xl:space-x-5">
            <div class="pr-5">
              <div class="min-w-0 max-w-xs flex-col space-y-0.5">
                <h2 class="text-black dark:text-white text-sm sm:text-sm lg:text-sm xl:text-sm font-semibold truncate">
                  <%= if @song, do: @song.title, else: raw("&nbsp;") %>
                </h2>
                <p class="text-gray-500 dark:text-gray-400 text-sm sm:text-sm lg:text-sm xl:text-sm font-medium">
                  <%= if @song, do: @song.artist, else: raw("&nbsp;") %>
                </p>
              </div>
            </div>
            <.progress_bar id="player-progress" />
            <div
              id="player-info"
              class="text-gray-500 dark:text-gray-400 flex-row justify-between text-sm font-medium tabular-nums"
              phx-update="ignore"
            >
              <div id="player-time"></div>
              <div id="player-duration"></div>
            </div>
          </div>
        </div>
        <div class="bg-gray-50 text-black dark:bg-gray-900 dark:text-white px-1 sm:px-3 lg:px-1 xl:px-3 grid grid-cols-3 items-center">
          <!-- prev -->
          <button
            type="button"
            class="sm:block xl:block mx-auto scale-75"
            phx-click={js_prev()}
            aria-label="Previous"
          >
            <svg width="17" height="18">
              <path d="M0 0h2v18H0V0zM4 9l13-9v18L4 9z" fill="currentColor" />
            </svg>
          </button>
          <!-- /prev -->
          <!-- play/pause -->
          <button
            type="button"
            class="mx-auto scale-75"
            phx-click={js_play_pause()}
            aria-label={
              if @playing do
                "Pause"
              else
                "Play"
              end
            }
          >
            <%= if @playing do %>
              <svg id="player-pause" width="50" height="50" fill="none">
                <circle
                  class="text-gray-300 dark:text-gray-500"
                  cx="25"
                  cy="25"
                  r="24"
                  stroke="currentColor"
                  stroke-width="1.5"
                />
                <path d="M18 16h4v18h-4V16zM28 16h4v18h-4z" fill="currentColor" />
              </svg>
            <% else %>
              <svg
                id="player-play"
                width="50"
                height="50"
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <circle
                  id="svg_1"
                  stroke-width="0.8"
                  stroke="currentColor"
                  r="11.4"
                  cy="12"
                  cx="12"
                  class="text-gray-300 dark:text-gray-500"
                />
                <path
                  stroke="null"
                  fill="currentColor"
                  transform="rotate(90 12.8947 12.3097)"
                  id="svg_6"
                  d="m9.40275,15.10014l3.49194,-5.58088l3.49197,5.58088l-6.98391,0z"
                  stroke-width="1.5"
                  fill="none"
                />
              </svg>
            <% end %>
          </button>
          <!-- /play/pause -->
          <!-- next -->
          <button
            type="button"
            class="mx-auto scale-75"
            phx-click={js_next()}
            aria-label="Next"
          >
            <svg width="17" height="18" viewBox="0 0 17 18" fill="none">
              <path d="M17 0H15V18H17V0Z" fill="currentColor" />
              <path d="M13 9L0 0V18L13 9Z" fill="currentColor" />
            </svg>
          </button>
          <!-- next -->
        </div>
      </div>
      <.modal
        id="enable-audio"
        on_confirm={js_listen_now() |> hide_modal("enable-audio")}
        data-js-show={show_modal("enable-audio")}
      >
        <:title>Start Listening now</:title>
        Your browser needs a click event to enable playback
        <:confirm>Listen Now</:confirm>
      </.modal>
    </div>
    <!-- /player -->
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        foo: true,
        song: nil,
        playing: false,
        profile: nil
      )

    send(self(), :play_current)

    if connected?(socket) do
      Player.subscribe()
    end

    {:ok, socket, layout: false, temporary_assigns: []}
  end

  def handle_event("play_pause", _, socket) do
    %{song: song, playing: playing} = socket.assigns
    song = Player.get_song!(song.id)

    cond do
      song && playing ->
        Player.pause_song(song)
        {:noreply, assign(socket, playing: false)}

      song ->
        Player.play_song(song)
        {:noreply, assign(socket, playing: true)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_event("next_song", _, socket) do
    %{song: song} = socket.assigns

    if song do
      Player.play_next_song()
    end

    {:noreply, socket}
  end

  def handle_event("prev_song", _, socket) do
    %{song: song} = socket.assigns

    if song do
      Player.play_prev_song()
    end

    {:noreply, socket}
  end

  def handle_event("next_song_auto", _, socket) do
    IO.inspect("playing next")

    if socket.assigns.song do
      Player.play_next_song_auto()
    end

    {:noreply, socket}
  end

  def handle_info(:play_current, socket) do
    {:noreply, play_current_song(socket)}
  end

  def handle_info({Player, %Player.Events.Pause{}}, socket) do
    {:noreply, push_pause(socket)}
  end

  def handle_info({Player, %Player.Events.Play{} = play}, socket) do
    {:noreply, play_song(socket, play.song, play.elapsed)}
  end

  def handle_info({Player, _}, socket), do: {:noreply, socket}

  defp play_song(socket, %Player.Song{} = song, elapsed) do
    socket
    |> push_play(song, elapsed)
    |> assign(song: song, playing: true, page_title: song_title(song))
  end

  defp stop_song(socket) do
    socket
    |> push_event("stop", %{})
    |> assign(song: nil, playing: false, page_title: "Listing Songs")
  end

  defp song_title(%{artist: artist, title: title}) do
    "#{title} - #{artist} (Now Playing)"
  end

  defp play_current_song(socket) do
    song = Player.get_current_active_song()

    cond do
      song && Player.playing?(song) ->
        play_song(socket, song, Player.elapsed_playback(song))

      song && Player.paused?(song) ->
        assign(socket, song: song, playing: false)

      true ->
        socket
    end
  end

  defp push_play(socket, %Player.Song{} = song, elapsed) do
    token =
      Phoenix.Token.encrypt(socket.endpoint, "file", %{
        vsn: 1,
        # ip: to_string(song.server_ip),
        size: song.mp3_filesize,
        uuid: song.mp3_filename
      })

    push_event(socket, "play", %{
      artist: song.artist,
      title: song.title,
      paused: Player.paused?(song),
      elapsed: elapsed,
      duration: song.duration,
      token: token,
      url: song.mp3_url
    })
  end

  defp push_pause(socket) do
    socket
    |> push_event("pause", %{})
    |> assign(playing: false)
  end

  defp js_play_pause do
    JS.push("play_pause")
    |> JS.dispatch("js:play_pause", to: "#audio-player")
  end

  defp js_prev do
    JS.push("prev_song")
  end

  defp js_next do
    JS.push("next_song")
  end

  defp js_listen_now(js \\ %JS{}) do
    JS.dispatch(js, "js:listen_now", to: "#audio-player")
  end

  defp toggle_player do
    JS.toggle(
      to: "#audio-controls",
      in: {"ease-out duration-300", "translate-y-full", "translate-y-0"},
      out: {"ease-in duration-200", "translate-y-0", "translate-y-full"}
    )
  end
end
