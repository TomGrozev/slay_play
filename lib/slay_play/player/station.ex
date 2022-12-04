defmodule SlayPlay.Player.Station do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stations" do
    field :name, :string
    field :transition_time_s, :integer, default: 15

    belongs_to :active_slide, SlayPlay.Player.Slide, on_replace: :update
    # belongs_to :playing_song, SlayPlay.Player.Song
  end

  @doc false
  def changeset(station, attrs) do
    station
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end

  def put_slide(%Ecto.Changeset{} = changeset, %SlayPlay.Player.Slide{id: id}) do
    put_change(changeset, :active_slide_id, id)
  end
end
