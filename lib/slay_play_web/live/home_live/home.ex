defmodule SlayPlayWeb.HomeLive.Home do
  use SlayPlayWeb, :live_view

  def mount(_params, _assigns, socket) do
    {:ok, assign(socket, :bg_path, "images/image1.jpg")}
  end
end
