defmodule TweetBot.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:access_token, :string)
    field(:access_token_secret, :string)
    field(:from_id, :integer)

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:from_id, :access_token, :access_token_secret])
    |> validate_required([:from_id], message: "不能留空")
    |> unique_constraint(:from_id, message: "已被占用")
  end
end
