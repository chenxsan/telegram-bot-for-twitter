defmodule TweetBot.UserTest do
  use TweetBot.DataCase

  alias TweetBot.Accounts.User

  @valid_attrs %{from_id: "123456"}
  @invalid_attrs %{from_id: nil}

  test "changeset with valid attributes" do
    changeset = User.changeset(%User{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = User.changeset(%User{}, @invalid_attrs)
    refute changeset.valid?
  end
end
