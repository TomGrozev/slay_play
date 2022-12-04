defmodule SlayPlay.Player.Song do
  use Ecto.Schema
  import Ecto.Changeset

  alias SlayPlay.Player.Song

  schema "songs" do
    field :album_artist, :string
    field :artist, :string
    field :played_at, :utc_datetime
    field :paused_at, :utc_datetime
    field :date_recorded, :naive_datetime
    field :date_released, :naive_datetime
    field :duration, :integer
    field :status, Ecto.Enum, values: [stopped: 1, playing: 2, paused: 3]
    field :title, :string
    field :mp3_url, :string
    field :mp3_filepath, :string
    field :mp3_filename, :string
    field :mp3_filesize, :integer, default: 0

    timestamps()
  end

  def playing?(%Song{} = song), do: song.status == :playing
  def paused?(%Song{} = song), do: song.status == :paused
  def stopped?(%Song{} = song), do: song.status == :stopped

  @doc false
  def changeset(song, attrs) do
    song
    |> cast(attrs, [:album_artist, :artist, :title, :date_released, :date_recorded])
    |> validate_required([:artist, :title])
    |> unique_constraint(:title,
      message: "is duplicated from another song",
      name: "songs_title_artist_index"
    )
  end

  def put_stats(%Ecto.Changeset{} = changeset, %SlayPlay.MP3Stat{} = stat) do
    changeset
    |> put_duration(stat.duration)
    |> put_change(:mp3_filesize, stat.size)
  end

  defp put_duration(%Ecto.Changeset{} = changeset, duration) when is_integer(duration) do
    changeset
    |> change(%{duration: duration})
    |> validate_number(:duration,
      greater_than: 0,
      less_than: 1200,
      message: "must be less than 20 minutes"
    )
  end

  def put_mp3_path(%Ecto.Changeset{} = changeset) do
    if changeset.valid? do
      filename = Ecto.UUID.generate() <> ".mp3"
      filepath = SlayPlay.Player.local_filepath(filename)

      changeset
      |> put_change(:mp3_filename, filename)
      |> put_change(:mp3_filepath, filepath)
      |> put_change(:mp3_url, mp3_url(filename))
    else
      changeset
    end
  end

  defp mp3_url(filename) do
    %{scheme: scheme, host: host, port: port} = Enum.into(SlayPlay.config([:files, :host]), %{})
    URI.to_string(%URI{scheme: scheme, host: host, port: port, path: "/files/songs/#{filename}"})
  end
end
