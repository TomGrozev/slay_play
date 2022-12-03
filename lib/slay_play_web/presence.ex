defmodule SlayPlayWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.
  """

  use Phoenix.Presence,
    otp_app: :slay_play,
    pubsub_server: SlayPlay.PubSub,
    presence: __MODULE__

  # use SlayPlayWeb, :html
end
