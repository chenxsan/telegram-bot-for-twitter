defmodule TweetBot.Repo.Migrations.AlterUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify(:from_id, :integer)
    end
  end
end
