defmodule SlayPlayWeb.AdminLive.Slides do
  use SlayPlayWeb, :live_view

  alias Phoenix.LiveView.JS
  alias SlayPlay.Player
  alias SlayPlayWeb.LayoutComponent
  alias SlayPlayWeb.AdminLive.{SlideRowComponent, SlideUploadFormComponent}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mt-4 flex justify-end items-center">
      <.button id="upload-btn" primary patch={Routes.admin_slides_path(@socket, :new)}>
        <.icon name={:plus} /><span class="ml-2">Create slide</span>
      </.button>
    </div>
    <div id="dialogs" phx-update="append">
      <%= for slide <- @slides, id = "delete-modal-#{slide.id}" do %>
        <.modal
          id={id}
          on_confirm={
            JS.push("delete", value: %{id: slide.id})
            |> hide_modal(id)
            |> focus_closest("#slide-#{slide.id}")
            |> hide("#slide-#{slide.id}")
          }
          on_cancel={focus("##{id}", "#delete-slide-#{slide.id}")}
        >
          Are you sure you want to delete "<%= slide.title %>"?
          <:cancel>Cancel</:cancel>
          <:confirm>Delete</:confirm>
        </.modal>
      <% end %>
    </div>
    <.live_table
      id="slides"
      module={SlideRowComponent}
      rows={@slides}
      row_id={fn slide -> "slide-#{slide.id}" end}
    >
      <:col :let={%{slide: slide}} label="Title"><%= slide.title %></:col>
      <:col :let={%{slide: slide}} label="Subtitle"><%= slide.subtitle %></:col>
      <:col :let={%{slide: slide}} label="">
        <.link
          id={"delete-slide-#{slide.id}"}
          phx-click={show_modal("delete-modal-#{slide.id}")}
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

    {:ok, list_slides(socket)}
  end

  def handle_params(params, _url, socket) do
    LayoutComponent.hide_modal()
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    slide = Player.get_slide(id)

    :ok = Player.delete_slide(slide)

    {:noreply, socket}
  end

  def handle_info({Player, %Player.Events.SlideCreated{slide: slide}}, socket) do
    {:noreply, update(socket, :slides, &(&1 ++ [slide]))}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing slides")
    |> assign(:slide, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Add slide")
    |> assign(:slide, %Player.Slide{})
    |> show_upload_modal()
  end

  defp show_upload_modal(socket) do
    LayoutComponent.show_modal(SlideUploadFormComponent, %{
      id: :new,
      confirm: {"Save", type: "submit", form: "slide-form"},
      patch: SlayPlayWeb.Router.Helpers.admin_slides_path(socket, :index),
      slide: socket.assigns.slide,
      title: socket.assigns.page_title
    })

    socket
  end

  defp list_slides(socket) do
    assign(socket, :slides, Player.list_slides())
  end
end
