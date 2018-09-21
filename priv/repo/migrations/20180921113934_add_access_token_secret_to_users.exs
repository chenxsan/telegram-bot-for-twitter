defmodule TweetBot.Repo.Migrations.AddAccessTokenSecretToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:access_token_secret, :string)
    end
  end
end
