defmodule SlayPlay.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: SlayPlay.TaskSupervisor},
      # Start the Ecto repository
      SlayPlay.Repo,
      # Start the Telemetry supervisor
      SlayPlayWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: SlayPlay.PubSub},
      # Start presence
      # SlayPlayWeb.Presence,
      # Start the Endpoint (http/https)
      SlayPlayWeb.Endpoint,
      # Start a worker by calling: SlayPlay.Worker.start_link(arg)
      # {SlayPlay.Worker, arg}
      SlayPlay.SlideClock
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SlayPlay.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SlayPlayWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
