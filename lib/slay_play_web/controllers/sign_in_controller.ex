defmodule SlayPlayWeb.SignInController do
  use SlayPlayWeb, :controller
  require Logger

  def index(conn, _params) do
    render(conn, "signin.html")
  end

  def new(conn, %{"password" => password}) do
    if verify_password(password) do
      conn
      |> put_flash(:info, "Welcome admin!")
      |> SlayPlayWeb.BasicAuth.log_in()
    else
      conn
      |> put_flash(:error, "Password is incorrect")
      |> redirect(to: SlayPlayWeb.Router.Helpers.sign_in_path(conn, :index))
    end
  end

  defp verify_password(password) do
    config = Application.fetch_env!(:slay_play, SlayPlayWeb.BasicAuth)
    correct_password = Keyword.fetch!(config, :password)

    Plug.Crypto.secure_compare(correct_password, password)
  end
end
