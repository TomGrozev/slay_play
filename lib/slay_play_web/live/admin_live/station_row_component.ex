defmodule SlayPlayWeb.AdminLive.StationRowComponent do
  use SlayPlayWeb, :live_component

  def render(assigns) do
    ~H"""
    <tr id={@id} class={@class} tabindex="0">
      <%= for col <- @col do %>
        <td
          class={
            "px-6 py-3 text-sm font-medium text-gray-900 #{col[:class]}"
          }
        >
          <div class="flex items-center space-x-3 lg:pl-2">
            <%= render_slot(col, assigns) %>
          </div>
        </td>
      <% end %>
    </tr>
    """
  end

  def update(assigns, socket) do
    {:ok,
     assign(socket,
       id: assigns.id,
       station: assigns.row,
       col: assigns.col,
       class: assigns.class,
       index: assigns.index
     )}
  end
end
