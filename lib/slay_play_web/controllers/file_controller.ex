defmodule SlayPlayWeb.FileController do
  @moduledoc """
  Serves files based on short-term token grants.
  """
  use SlayPlayWeb, :controller

  alias SlayPlay.Player

  require Logger

  def show(conn, %{"id" => filename_uuid, "token" => token}) do
    path = Player.local_filepath(filename_uuid)

    case Phoenix.Token.decrypt(conn, "file", token, max_age: :timer.minutes(1)) do
      {:ok, %{vsn: 1, uuid: ^filename_uuid, size: size}} ->
        Logger.info("serving file from local")
        do_send_file(conn, path)

      {:ok, _} ->
        send_resp(conn, :unauthorized, "")

      {:error, _} ->
        send_resp(conn, :unauthorized, "")
    end
  end

  defp do_send_file(conn, path) do
    conn
    |> put_resp_header("content-type", MIME.from_path(path))
    |> put_resp_header("accept-ranges", "bytes")
    |> send_file(200, path)
  end
end
