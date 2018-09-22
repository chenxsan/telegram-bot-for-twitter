defmodule TweetBot.Repo.Migrations.AlterUsers do
  use Ecto.Migration

  def change do
    execute(
      "alter table users alter column from_id type integer using (from_id::integer)",
      "alter table users alter column from_id type character varying(255)"
    )
  end
end
