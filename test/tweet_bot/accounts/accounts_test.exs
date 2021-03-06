defmodule TweetBot.AccountsTest do
  use TweetBot.DataCase

  alias TweetBot.Accounts

  describe "users" do
    alias TweetBot.Accounts.User

    @valid_attrs %{access_token: "some access_token", from_id: 1}
    @update_attrs %{access_token: "some updated access_token", from_id: 2}
    @invalid_attrs %{access_token: nil, from_id: nil}

    test "from_id should be required" do
      changeset = User.changeset(%User{}, @valid_attrs |> Map.delete(:from_id))
      refute changeset.valid?
      assert %{from_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "from_id should be unique" do
      assert {:ok, _} = Accounts.create_user(@valid_attrs)
      assert {:error, changeset} = Accounts.create_user(@valid_attrs)
      assert %{from_id: ["has already been taken"]} = errors_on(changeset)
    end

    def user_fixture(attrs \\ %{}) do
      {:ok, user} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Accounts.create_user()

      user
    end

    test "list_users/0 returns all users" do
      user = user_fixture()
      assert Accounts.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Accounts.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      assert {:ok, %User{} = user} = Accounts.create_user(@valid_attrs)
      assert user.access_token == "some access_token"
      assert user.from_id == 1
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      assert {:ok, user} = Accounts.update_user(user, @update_attrs)
      assert %User{} = user
      assert user.access_token == "some updated access_token"
      assert user.from_id == 2
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      assert user == Accounts.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end
  end
end
