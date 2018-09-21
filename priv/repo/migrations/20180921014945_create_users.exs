defmodule TweetBot.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :from_id, :string
      add :access_token, :string

      timestamps()
    end

    create unique_index(:users, [:from_id])
  end
end
