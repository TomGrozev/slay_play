defmodule SlayPlay.Repo.Migrations.CreateSongs do
  use Ecto.Migration

  def change do
    create table(:songs) do
      add(:album_artist, :string)
      add(:artist, :string, null: false)
      add(:duration, :integer, default: 0, null: false)
      add(:status, :integer, null: false, default: 1)
      add(:played_at, :utc_datetime)
      add(:paused_at, :utc_datetime)
      add(:title, :string, null: false)
      add(:mp3_url, :string, null: false)
      add(:mp3_filename, :string, null: false)
      add(:mp3_filepath, :string, null: false)
      add(:date_recorded, :naive_datetime)
      add(:date_released, :naive_datetime)

      timestamps()
    end

    create(unique_index(:songs, [:title, :artist]))
    create(index(:songs, [:status]))
  end
end
