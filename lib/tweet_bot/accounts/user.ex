defmodule TweetBot.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:access_token, :string)
    field(:from_id, :string)

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:from_id, :access_token])
    |> validate_required([:from_id])
    |> unique_constraint(:from_id)
  end
end
