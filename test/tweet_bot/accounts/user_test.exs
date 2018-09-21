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

  test "from_id should be required" do
    changeset = User.changeset(%User{}, @invalid_attrs)
    assert %{from_id: ["不能留空"]} = errors_on(changeset)
  end

  test "from_id should be unique" do
    changeset = User.changeset(%User{}, @valid_attrs)
    assert Repo.insert!(changeset)
    assert {:error, changeset} = Repo.insert(changeset)
    assert %{from_id: ["已被占用"]} = errors_on(changeset)
  end
end
