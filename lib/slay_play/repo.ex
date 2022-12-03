defmodule SlayPlay.Repo do
  use Ecto.Repo,
    otp_app: :slay_play,
    adapter: Ecto.Adapters.Postgres
end
