defmodule SlayPlayWeb.AdminLive.SlideUploadFormComponent do
  use SlayPlayWeb, :live_component

  alias SlayPlay.Player

  @impl true
  def update(%{slide: slide} = assigns, socket) do
    changeset = Player.change_slide(slide)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(changeset: changeset, error_messages: nil)
     |> assign_new(:progress, fn -> 0 end)
     |> allow_upload(:bg,
       slide_id: slide.id,
       auto_upload: true,
       progress: &handle_progress/3,
       accept: ~w(.jpg .jpeg .png),
       max_file_size: 20_000_000,
       chunk_size: 64_000 * 3
     )}
  end

  @impl true
  def handle_event("validate", %{"_target" => ["img"]}, socket) do
    case uploaded_entries(socket, :bg) do
      {[], [_]} ->
        {:noreply, drop_invalid_uploads(socket)}

      {_, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("validate", %{"slide" => params}, socket) do
    changeset =
      socket.assigns.slide
      |> Player.change_slide(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"slide" => params}, socket) do
    with {[bg], []} <- uploaded_entries(socket, :bg),
         {:ok, slide} <- Player.create_slide(params, bg.client_type, &consume_entry(socket, &1)) do
      {:noreply,
       socket
       |> put_flash(:info, "Created slide")
       |> push_patch(to: SlayPlayWeb.Router.Helpers.admin_slides_path(socket, :index))}
    else
      {[], []} ->
        {:noreply, put_error(socket, {nil, :missing})}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("save", %{} = _params, socket) do
    {:noreply, socket}
  end

  defp consume_entry(socket, store_func) when is_function(store_func) do
    {[bg], []} = uploaded_entries(socket, :bg)
    consume_uploaded_entry(socket, bg, fn meta -> {:ok, store_func.(meta.path)} end)
  end

  defp handle_progress(:bg, entry, socket) do
    {:noreply, assign(socket, :progress, entry.progress)}
  end

  defp file_error(%{kind: :dropped} = assigns),
    do: ~H|<%= @label %>: dropped (exceeds limit of 1 file)|

  defp file_error(%{kind: :too_large} = assigns),
    do: ~H|<%= @label %>: larger than 20MB|

  defp file_error(%{kind: :not_accepted} = assigns),
    do: ~H|<%= @label %>: not a valid image file|

  defp file_error(%{kind: :too_many_files} = assigns),
    do: ~H|too many files|

  defp file_error(%{kind: :songs_limit_exceeded} = assigns),
    do: ~H|You exceeded the limit of songs per account|

  defp file_error(%{kind: :invalid} = assigns),
    do: ~H|Something went wrong|

  defp file_error(%{kind: :missing} = assigns),
    do: ~H|Missing background image|

  defp file_error(%{kind: %Ecto.Changeset{}} = assigns),
    do: ~H|<%= @label %>: <%= translate_changeset_errors(@kind) %>|

  defp file_error(%{kind: {msg, opts}} = assigns) when is_binary(msg) and is_list(opts),
    do: ~H|<%= @label %>: <%= translate_error(@kind) %>|

  defp drop_invalid_uploads(socket) do
    %{uploads: uploads} = socket.assigns

    Enum.reduce(uploads.img.entries, socket, fn entry, socket ->
      case upload_errors(uploads.img, entry) do
        [first | _] ->
          cancel_changeset_upload(socket, entry, first)

        [] ->
          socket
      end
    end)
  end

  defp cancel_changeset_upload(socket, entry, reason) do
    socket
    |> cancel_upload(:bg, entry.ref)
    |> put_error({entry.client_name, reason})
  end

  defp put_error(socket, {label, msg}) do
    assign(socket, :error_messages, {label, msg})
  end
end
