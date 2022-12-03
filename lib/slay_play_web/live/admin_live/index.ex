defmodule SlayPlayWeb.AdminLive.Index do
  use SlayPlayWeb, :live_view

  alias SlayPlay.Player
  alias SlayPlayWeb.LayoutComponent
  alias SlayPlayWeb.AdminLive.SongUploadFormComponent

  @impl true
  def mount(_params, _assigns, socket) do
    {:ok, socket}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Add Music")
    |> assign(:song, %Player.Song{})
    |> show_upload_modal()
  end

  defp show_upload_modal(socket) do
    LayoutComponent.show_modal(SongUploadFormComponent, %{
      id: :new,
      confirm: {"Save", type: "submit", form: "song-form"},
      patch: "",
      song: socket.assigns.song,
      title: socket.assigns.page_title
    })

    socket
  end
end
