defmodule SlayPlayWeb.AdminLive.SlideRowComponent do
  use SlayPlayWeb, :live_component

  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <tr id={@id} class={@class} tabindex="0">
      <%= for {col, i} <- Enum.with_index(@col) do %>
        <td
          class={
            "px-6 py-3 text-sm font-medium text-gray-900 #{col[:class]}"
          }
          phx-click={JS.push("set_slide", value: %{id: @slide.id})}
        >
          <div class="flex items-center space-x-3 lg:pl-2">
            <%= if i == 0 do %>
              <%= if @active == @slide.id do %>
                <span class="flex pt-1 relative mr-2 w-4">
                  <span class="w-3 h-3 animate-ping bg-purple-400 rounded-full absolute"></span>
                  <.icon
                    name={:presentation_chart_line}
                    class="h-5 w-5 -mt-1 -ml-1"
                    aria-label="Active"
                    role="button"
                  />
                </span>
              <% else %>
                <span class="flex pt-1 relative mr-2 w-4">
                  <.icon
                    name={:presentation_chart_line}
                    class="h-5 w-5 -mt-1 -ml-1 text-gray-400"
                    aria-label="Inactive"
                    role="button"
                  />
                </span>
              <% end %>
            <% end %>
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
       slide: assigns.row,
       col: assigns.col,
       class: assigns.class,
       index: assigns.index,
       active: assigns.active_id
     )}
  end
end
