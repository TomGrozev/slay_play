defmodule SlayPlayWeb.HomeLive.Home do
  use SlayPlayWeb, :live_view

  alias SlayPlay.Player

  def mount(_params, _assigns, socket) do
    if connected?(socket) do
      Player.subscribe()
    end

    set_current_slide()

    {:ok, socket, temporary_assigns: [bg_path: "", title: "", subtitle: ""]}
  end

  def handle_info({Player, %Player.Events.SlideChanged{station: _station, slide: slide}}, socket) do
    {:noreply, push_slide(socket, slide)}
  end

  def handle_info({Player, _}, socket) do
    {:noreply, socket}
  end

  defp set_current_slide do
    current_slide = Player.get_current_active_slide("default")

    send(self(), {Player, %Player.Events.SlideChanged{station: nil, slide: current_slide}})
  end

  defp push_slide(socket, nil) do
    socket
    |> assign(
      title: "Welcome",
      subtitle: "No slides created yet :O",
      bg_path: "images/image1.jpg"
    )
  end

  defp push_slide(socket, slide) do
    token =
      Phoenix.Token.encrypt(socket.endpoint, "file", %{
        vsn: 1,
        uuid: slide.img_name
      })

    socket
    |> assign(
      title: slide.title,
      subtitle: slide.subtitle || "",
      bg_path: Player.slide_img_url(slide, token)
    )
  end
end
