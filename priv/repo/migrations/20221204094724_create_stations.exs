defmodule SlayPlay.Repo.Migrations.CreateStations do
  use Ecto.Migration

  def change do
    create table(:stations) do
      add(:name, :string, null: false)
      add(:transition_time_s, :integer, default: 15)
      add(:active_slide_id, references(:slides, on_delete: :nilify_all))

      timestamps()
    end

    execute(
      "INSERT INTO stations (name, inserted_at, updated_at) VALUES ('default', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
      ""
    )
  end
end
