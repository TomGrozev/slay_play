defmodule SlayPlay.Repo.Migrations.CreateSlides do
  use Ecto.Migration

  def change do
    create table(:slides) do
      add(:title, :string, null: false)
      add(:subtitle, :string)
      add(:img_name, :string, null: false)

      timestamps()
    end
  end
end
