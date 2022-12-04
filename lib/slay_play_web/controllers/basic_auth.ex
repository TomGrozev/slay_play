defmodule SlayPlayWeb.BasicAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias Phoenix.LiveView

  @realm "Basic realm=\"SlayPlay Admin\""

  def on_mount(:ensure_authenticated, _params, session, socket) do
    case session do
      %{"logged_in" => true} ->
        new_socket = Phoenix.Component.assign_new(socket, :logged_in, fn -> true end)

        {:cont, new_socket}

      %{} ->
        {:halt, redirect_require_login(socket)}
    end
  end

  defp redirect_require_login(socket) do
    socket
    |> LiveView.put_flash(:error, "Please sign in")
    |> LiveView.redirect(to: SlayPlayWeb.Router.Helpers.sign_in_path(socket, :index))
  end

  def log_in(conn) do
    conn
    |> assign(:logged_in, true)
    |> renew_session()
    |> put_session(:logged_in, true)
    |> put_session(:live_socket_id, "user_sessions:admin")
    |> redirect(to: SlayPlayWeb.Router.Helpers.admin_index_path(conn, :index))
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  def redirect_if_authenticated(conn, _opts) do
    if get_session(conn, :logged_in) do
      conn
      |> redirect(to: SlayPlayWeb.Router.Helpers.admin_index_path(conn, :index))
      |> halt()
    else
      conn
    end
  end

  def require_authenticated(conn, _opts) do
    if get_session(conn, :logged_in) do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page.")
      |> redirect(to: SlayPlayWeb.Router.Helpers.sign_in_path(conn, :index))
      |> halt()
    end
  end

  def init(opts), do: opts

  def call(conn, correct_auth) do
    case get_req_header(conn, "authorization") do
      ["Basic " <> attempted_auth] -> verify(conn, attempted_auth, correct_auth)
      _ -> unauthorized(conn)
    end
  end

  defp verify(conn, attempted_auth, username: username, passowrd: password) do
    case encode(username, password) do
      ^attempted_auth -> conn
      _ -> unauthorized(conn)
    end
  end

  defp encode(username, password), do: Base.encode64(username <> ":" <> password)

  defp unauthorized(conn) do
    conn
    |> put_resp_header("www-authenticate", @realm)
    |> send_resp(401, "unauthorized")
    |> halt()
  end
end
