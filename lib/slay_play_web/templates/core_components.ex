defmodule SlayPlayWeb.CoreComponents do
  use Phoenix.Component

  import SlayPlayWeb.ErrorHelpers

  alias Phoenix.LiveView.JS

  slot(:inner_block)

  def connection_status(assigns) do
    ~H"""
    <div
      id="connection-status"
      class="hidden rounded-md bg-red-50 p-4 fixed top-1 right-1 w-96 fade-in-scale z-50"
      js-show={show("#connection-status")}
      js-hide={hide("#connection-status")}
    >
      <div class="flex">
        <div class="flex-shrink-0">
          <svg
            class="animate-spin -ml-1 mr-3 h-5 w-5 text-red-800"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
            </circle>
            <path
              class="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            >
            </path>
          </svg>
        </div>
        <div class="ml-3">
          <p class="text-sm font-medium text-red-800" role="alert">
            <%= render_slot(@inner_block) %>
          </p>
        </div>
      </div>
    </div>
    """
  end

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      display: "inline-block",
      transition:
        {"ease-out duration-300", "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 300,
      transition:
        {"transition ease-in duration-300", "transform opacity-100 scale-100",
         "transform opacity-0 scale-95"}
    )
  end

  attr :patch, :string
  attr :primary, :boolean, default: false
  attr :rest, :global

  slot(:inner_block)

  def button(%{patch: _} = assigns) do
    ~H"""
    <%= if @primary do %>
      <%= live_patch [to: @patch, class: "order-0 inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-purple-600 hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500 sm:order-1 sm:ml-3"] ++
        Map.to_list(@rest) do %>
        <%= render_slot(@inner_block) %>
      <% end %>
    <% else %>
      <%= live_patch [to: @patch, class: "order-1 inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500 sm:order-0 sm:ml-0 lg:ml-3"] ++
        assigns_to_attributes(assigns, [:primary, :patch]) do %>
        <%= render_slot(@inner_block) %>
      <% end %>
    <% end %>
    """
  end

  attr :id, :string, required: true
  attr :min, :integer, default: 0
  attr :max, :integer, default: 100
  attr :value, :integer

  def progress_bar(assigns) do
    assigns = assign_new(assigns, :value, fn -> assigns[:min] || 0 end)

    ~H"""
    <div
      id={"#{@id}-container"}
      class="bg-gray-200 flex-auto dark:bg-black rounded-full overflow-hidden"
      phx-update="ignore"
    >
      <div
        id={@id}
        class="bg-lime-500 dark:bg-lime-400 h-1.5 w-0"
        data-min={@min}
        data-max={@max}
        data-val={@value}
      >
      </div>
    </div>
    """
  end

  attr :flash, :map
  attr :kind, :atom

  def flash(%{kind: :error} = assigns) do
    ~H"""
    <div
      :if={msg = live_flash(@flash, @kind)}
      id="flash"
      class="rounded-md bg-red-50 p-4 fixed top-1 right-1 w-96 fade-in-scale z-50"
      phx-click={
        JS.push("lv:clear-flash")
        |> JS.remove_class("fade-in-scale", to: "#flash")
        |> hide("#flash")
      }
      phx-hook="Flash"
    >
      <div class="flex justify-between items-center space-x-3 text-red-700">
        <.icon name={:exclamation_circle} class="w-5 w-5" />
        <p class="flex-1 text-sm font-medium" role="alert">
          <%= msg %>
        </p>
        <button
          type="button"
          class="inline-flex bg-red-50 rounded-md p-1.5 text-red-500 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-red-50 focus:ring-red-600"
        >
          <.icon name={:x_mark} class="w-4 h-4" />
        </button>
      </div>
    </div>
    """
  end

  def flash(%{kind: :info} = assigns) do
    ~H"""
    <div
      :if={msg = live_flash(@flash, @kind)}
      id="flash"
      class="rounded-md bg-green-50 p-4 fixed top-1 right-1 w-96 fade-in-scale z-50"
      phx-click={JS.push("lv:clear-flash") |> JS.remove_class("fade-in-scale") |> hide("#flash")}
      phx-value-key="info"
      phx-hook="Flash"
    >
      <div class="flex justify-between items-center space-x-3 text-green-700">
        <.icon name={:check_circle} class="w-5 h-5" />
        <p class="flex-1 text-sm font-medium" role="alert">
          <%= msg %>
        </p>
        <button
          type="button"
          class="inline-flex bg-green-50 rounded-md p-1.5 text-green-500 hover:bg-green-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-green-50 focus:ring-green-600"
        >
          <.icon name={:x_mark} class="w-4 h-4" />
        </button>
      </div>
    </div>
    """
  end

  def spinner(assigns) do
    ~H"""
    <svg
      class="inline-block animate-spin h-2.5 w-2.5 text-gray-400"
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      aria-hidden="true"
    >
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
      </circle>
      <path
        class="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
      >
      </path>
    </svg>
    """
  end

  def error(%{errors: errors, field: field} = assigns) do
    assigns =
      assigns
      |> assign(:error_values, Keyword.get_values(errors, field))
      |> assign_new(:class, fn -> "" end)

    ~H"""
    <%= for error <- @error_values do %>
      <span
        phx-feedback-for={@input_name}
        class={
          "invalid-feedback inline-block pl-2 pr-2 text-sm text-white bg-red-600 rounded-md #{@class}"
        }
      >
        <%= translate_error(error) %>
      </span>
    <% end %>
    <%= if Enum.empty?(@error_values) do %>
      <span class={"invalid-feedback inline-block h-0 #{@class}"}></span>
    <% end %>
    """
  end

  attr :name, :atom, required: true
  attr :outlined, :boolean, default: false
  attr :rest, :global, default: %{class: "w-4 h-4 inline-block"}

  def icon(assigns) do
    assigns = assign_new(assigns, :"aria-hidden", fn -> !Map.has_key?(assigns, :"aria-label") end)

    ~H"""
    <%= apply(Heroicons, @name, [Map.merge(@rest, %{__changed__: nil, solid: not @outlined})]) %>
    """
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(
      to: "##{id}",
      display: "inline-block",
      transition: {"ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "##{id}-container",
      display: "inline-block",
      transition:
        {"ease-out duration-300", "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
    |> js_exec("##{id}-confirm", "focus", [])
  end

  def hide_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.remove_class("fade-in", to: "##{id}")
    |> JS.hide(
      to: "##{id}",
      transition: {"ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "##{id}-container",
      transition:
        {"ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
    |> JS.dispatch("click", to: "##{id} [data-modal-return]")
  end

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :patch, :string, default: nil
  attr :navigate, :string, default: nil
  attr :on_cancel, JS, default: %JS{}
  attr :on_confirm, JS, default: %JS{}
  attr :rest, :global

  slot(:title)
  slot(:confirm)
  slot(:cancel)

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      class={"fixed z-10 inset-0 overflow-y-auto #{if @show, do: "fade-in", else: "hidden"}"}
      {@rest}
    >
      <.focus_wrap id={"#{@id}-focus-wrap"}>
        <div
          class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0"
          aria-labelledby={"#{@id}-title"}
          aria-describedby={"#{@id}-description"}
          role="dialog"
          aria-modal="true"
          tabindex="0"
        >
          <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true">
          </div>
          <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">
            &#8203;
          </span>
          <div
            id={"#{@id}-container"}
            class={
              "#{if @show, do: "fade-in-scale", else: "hidden"} sticky inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform sm:my-8 sm:align-middle sm:max-w-xl sm:w-full sm:p-6"
            }
            phx-window-keydown={hide_modal(@on_cancel, @id)}
            phx-key="escape"
            phx-click-away={hide_modal(@on_cancel, @id)}
          >
            <%= if @patch do %>
              <.link patch={@patch} data-modal-return class="hidden"></.link>
            <% end %>
            <%= if @navigate do %>
              <.link navigate={@navigate} data-modal-return class="hidden"></.link>
            <% end %>
            <div class="sm:flex sm:items-start">
              <div class="mx-auto flex-shrink-0 flex items-center justify-center h-8 w-8 rounded-full bg-purple-100 sm:mx-0">
                <!-- Heroicon name: outline/plus -->
                <.icon name={:information_circle} outlined class="h-6 w-6 text-purple-600" />
              </div>
              <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full mr-12">
                <h3 class="text-lg leading-6 font-medium text-gray-900" id={"#{@id}-title"}>
                  <%= render_slot(@title) %>
                </h3>
                <div class="mt-2">
                  <p id={"#{@id}-content"} class="text-sm text-gray-500">
                    <%= render_slot(@inner_block) %>
                  </p>
                </div>
              </div>
            </div>
            <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
              <%= for confirm <- @confirm do %>
                <button
                  id={"#{@id}-confirm"}
                  class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-red-600 text-base font-medium text-white hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 sm:ml-3 sm:w-auto sm:text-sm"
                  phx-click={@on_confirm}
                  phx-disable-with
                  {assigns_to_attributes(confirm)}
                >
                  <%= render_slot(confirm) %>
                </button>
              <% end %>
              <%= for cancel <- @cancel do %>
                <button
                  class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:w-auto sm:text-sm"
                  phx-click={hide_modal(@on_cancel, @id)}
                  {assigns_to_attributes(cancel)}
                >
                  <%= render_slot(cancel) %>
                </button>
              <% end %>
            </div>
          </div>
        </div>
      </.focus_wrap>
    </div>
    """
  end

  attr :id, :any, required: true
  attr :module, :atom, required: true
  attr :row_id, :any, default: false
  attr :rows, :list, required: true
  attr :active_id, :any, default: nil

  slot :col do
    attr :label, :string
    attr :class, :string
  end

  def live_table(assigns) do
    assigns = assign(assigns, :col, for(col <- assigns.col, col[:if] != false, do: col))

    ~H"""
    <div class="hidden mt-8 sm:block">
      <div class="align-middle inline-block min-w-full border-b border-gray-200">
        <table class="min-w-full">
          <thead>
            <tr class="border-t border-gray-200">
              <%= for col <- @col do %>
                <th class="px-6 py-3 border-b border-gray-200 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  <span class="lg:pl-2"><%= col.label %></span>
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody id={@id} class="bg-white divide-y divide-gray-100" phx-update="append">
            <%= for {row, i} <- Enum.with_index(@rows) do %>
              <.live_component
                module={@module}
                id={@row_id.(row)}
                row={row}
                col={@col}
                index={i}
                active_id={@active_id}
                class="hover:bg-gray-50"
                ,
              />
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  @doc """
  Calls a wired up event listener to call a function with arguments

    window.addEventListener("js:exec", e => e.target[e.detail.call](...e.detail.args))
  """
  def js_exec(js \\ %JS{}, to, call, args) do
    JS.dispatch(js, "js:exec", to: to, detail: %{call: call, args: args})
  end

  def focus(js \\ %JS{}, parent, to) do
    JS.dispatch(js, "js:focus", to: to, detail: %{parent: parent})
  end

  def focus_closest(js \\ %JS{}, to) do
    js
    |> JS.dispatch("js:focus-closest", to: to)
    |> hide(to)
  end
end
