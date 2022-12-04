defmodule SlayPlay.Player.Slide do
  use Ecto.Schema
  import Ecto.Changeset

  schema "slides" do
    field :title, :string
    field :subtitle, :string
    field :img_name, :string

    timestamps()
  end

  @doc false
  def changeset(song, attrs) do
    song
    |> cast(attrs, [:title, :subtitle, :img_name])
    |> validate_required([:title])
  end

  def put_img_name(%Ecto.Changeset{} = changeset, extension) when is_binary(extension) do
    if changeset.valid? do
      filename = Ecto.UUID.generate() <> ".#{extension}"

      put_change(changeset, :img_name, filename)
    else
      changeset
    end
  end

  def img_url(filename) do
    %{scheme: scheme, host: host, port: port} = Enum.into(SlayPlay.config([:files, :host]), %{})
    URI.to_string(%URI{scheme: scheme, host: host, port: port, path: "/files/#{filename}"})
  end
end
