# 用户授权了吗？

在我的设计里，所有的消息，是一定都会检查该用户是否已授权的。

这种场景非常适合 [Plug](https://hexdocs.pm/phoenix/plug.html) 来处理，这里我们在 `twitter_controller.ex` 文件里新增一个 function plug。

```elixir
  alias TweetBot.Accounts
  plug(:find_user)

  defp find_user(conn, _) do
    %{"message" => %{"from" => %{"id" => from_id}}} = conn.params

    case Accounts.get_user_by_from_id(from_id) do
      user when not is_nil(user) ->
        assign(conn, :current_user, user.from_id)

      nil ->
        token =
          ExTwitter.request_token(
            URI.encode_www_form(
              TweetBotWeb.Router.Helpers.auth_url(conn, :callback) <> "?from_id=#{from_id}"
            )
          )

        {:ok, authenticate_url} = ExTwitter.authenticate_url(token.oauth_token)

        sendMessage(
          from_id,
          "请点击链接登录您的 Twitter 账号授权：<a href='" <> authenticate_url <> "'>登录 Twitter</a>",
          parse_mode: "HTML"
        )

        conn |> halt()
    end
  end
```

现在会报 `Accounts.get_user_by_from_id` 未找到的错误，因为我们还没有定义它。

打开 `accounts.ex` 文件，添加方法：

```elixir
  def get_user_by_from_id(from_id) do
    Repo.get_by(User, from_id: from_id)
  end
```
不过还是会报错：

> [debug] ** (Ecto.Query.CastError) deps/ecto/lib/ecto/repo/queryable.ex:357: value `48885097` in `where` cannot be cast to type :string in query:

这是因为我们在定义 `User` 时，`from_id` 是一个字符串，而 `conn.params` 中解析出的却是数值。我们可以粗暴一点，直接做类型转换：

```elixir
Repo.get_by(User, from_id: Integer.to_string(from_id))
```
但长远来说，这只是个 workaround，不是真正的解决办法。

下面我们将通过 migration 调整 `User` 中 `from_id` 的类型。

## Migration

创建一个 migration：

```sh
$ mix ecto.gen.migration alter_users
* creating priv/repo/migrations
* creating priv/repo/migrations/20180921133030_alter_users.exs
```
打开新建的文件，修改内容如下：

```elixir
+defmodule TweetBot.Repo.Migrations.AlterUsers do
+  use Ecto.Migration
+
+  def change do
+    alter table(:users) do
+      modify(:from_id, :integer)
+    end
+  end
+end
```
运行 `mix ecto.migrate`：

```sh
$ mix ecto.migrate
[info] == Running TweetBot.Repo.Migrations.AlterUsers.change/0 forward
[info] alter table users
** (Postgrex.Error) ERROR 42804 (datatype_mismatch): column "from_id" cannot be cast automatically to type integer
```
报错了。我怀疑是不是因为数据库中已经有数据导致的，就删库重试：

```sh
$ mix ecto.drop
$ mix ecto.create
$ mix ecto.migrate
```
仍然报错。Google 扫了一圈没找到答案，只好到 [elixir forum 提问](https://elixirforum.com/t/postgrex-error-error-42804-datatype-mismatch-column-cannot-be-cast-automatically-to-type-integer/16776)，好了，有回复：

```elixir
  def change do
    execute(
      "alter table users alter column from_id type integer using (from_id::integer)",
      "alter table users alter column from_id type character varying(255)"
    )
  end
```
重新运行 `mix ecto.migrate`，成功。

此外还要调整下 `user.ex` 文件：

```elixir
     field :access_token, :string
-    field :from_id, :string
+    field :from_id, :integer
     field :access_token_secret, :string
```
因为我们调整了 `:from_id` 的类型，可以预计，`mix test` 一定会报错。

```sh
$ mix test
..

  1) test users create_user/1 with valid data creates a user (TweetBot.AccountsTest)
     test/tweet_bot/accounts/accounts_test.exs:32
     match (=) failed
     code:  assert {:ok, %User{} = user} = Accounts.create_user(@valid_attrs)
     right: {:error,
             #Ecto.Changeset<
               action: :insert,
               changes: %{access_token: "some access_token"},
               errors: [
                 from_id: {"is invalid", [type: :integer, validation: :cast]}
               ],
               data: #TweetBot.Accounts.User<>,
               valid?: false
             >}
     stacktrace:
       test/tweet_bot/accounts/accounts_test.exs:33: (test)



  2) test users update_user/2 with valid data updates the user (TweetBot.AccountsTest)
     test/tweet_bot/accounts/accounts_test.exs:42
     ** (MatchError) no match of right hand side value: {:error, #Ecto.Changeset<action: :insert, changes: %{access_token: "some access_token"}, errors: [from_id: {"is invalid", [type: :integer, validation: :cast]}], data: #TweetBot.Accounts.User<>, valid?: false>}
     code: user = user_fixture()
     stacktrace:
       test/tweet_bot/accounts/accounts_test.exs:14: TweetBot.AccountsTest.user_fixture/1
       test/tweet_bot/accounts/accounts_test.exs:43: (test)



  3) test users list_users/0 returns all users (TweetBot.AccountsTest)
     test/tweet_bot/accounts/accounts_test.exs:22
     ** (MatchError) no match of right hand side value: {:error, #Ecto.Changeset<action: :insert, changes: %{access_token: "some access_token"}, errors: [from_id: {"is invalid", [type: :integer, validation: :cast]}], data: #TweetBot.Accounts.User<>, valid?: false>}
     code: user = user_fixture()
     stacktrace:
       test/tweet_bot/accounts/accounts_test.exs:14: TweetBot.AccountsTest.user_fixture/1
       test/tweet_bot/accounts/accounts_test.exs:23: (test)



  4) test users change_user/1 returns a user changeset (TweetBot.AccountsTest)
     test/tweet_bot/accounts/accounts_test.exs:62
     ** (MatchError) no match of right hand side value: {:error, #Ecto.Changeset<action: :insert, changes: %{access_token: "some access_token"}, errors: [from_id: {"is invalid", [type: :integer, validation: :cast]}], data: #TweetBot.Accounts.User<>, valid?: false>}
     code: user = user_fixture()
     stacktrace:
       test/tweet_bot/accounts/accounts_test.exs:14: TweetBot.AccountsTest.user_fixture/1
       test/tweet_bot/accounts/accounts_test.exs:63: (test)



  5) test users get_user!/1 returns the user with given id (TweetBot.AccountsTest)
     test/tweet_bot/accounts/accounts_test.exs:27
     ** (MatchError) no match of right hand side value: {:error, #Ecto.Changeset<action: :insert, changes: %{access_token: "some access_token"}, errors: [from_id: {"is invalid", [type: :integer, validation: :cast]}], data: #TweetBot.Accounts.User<>, valid?: false>}
     code: user = user_fixture()
     stacktrace:
       test/tweet_bot/accounts/accounts_test.exs:14: TweetBot.AccountsTest.user_fixture/1
       test/tweet_bot/accounts/accounts_test.exs:28: (test)



  6) test users delete_user/1 deletes the user (TweetBot.AccountsTest)
     test/tweet_bot/accounts/accounts_test.exs:56
     ** (MatchError) no match of right hand side value: {:error, #Ecto.Changeset<action: :insert, changes: %{access_token: "some access_token"}, errors: [from_id: {"is invalid", [type: :integer, validation: :cast]}], data: #TweetBot.Accounts.User<>, valid?: false>}
     code: user = user_fixture()
     stacktrace:
       test/tweet_bot/accounts/accounts_test.exs:14: TweetBot.AccountsTest.user_fixture/1
       test/tweet_bot/accounts/accounts_test.exs:57: (test)



  7) test users update_user/2 with invalid data returns error changeset (TweetBot.AccountsTest)
     test/tweet_bot/accounts/accounts_test.exs:50
     ** (MatchError) no match of right hand side value: {:error, #Ecto.Changeset<action: :insert, changes: %{access_token: "some access_token"}, errors: [from_id: {"is invalid", [type: :integer, validation: :cast]}], data: #TweetBot.Accounts.User<>, valid?: false>}
     code: user = user_fixture()
     stacktrace:
       test/tweet_bot/accounts/accounts_test.exs:14: TweetBot.AccountsTest.user_fixture/1
       test/tweet_bot/accounts/accounts_test.exs:51: (test)

......

Finished in 0.1 seconds
15 tests, 7 failures

Randomized with seed 546517
➜  tweet_bot git:(master) ✗
➜  tweet_bot git:(master) ✗ mix ecto.migrate
[info] == Running TweetBot.Repo.Migrations.AlterUsers.change/0 forward
[info] alter table users
[info] == Migrated in 0.0s
➜  tweet_bot git:(master) ✗
➜  tweet_bot git:(master) ✗ mix test
..

  1) test users list_users/0 returns all users (TweetBot.AccountsTest)
     test/tweet_bot/accounts/accounts_test.exs:22
     ** (MatchError) no match of right hand side value: {:error, #Ecto.Changeset<action: :insert, changes: %{access_token: "some access_token"}, errors: [from_id: {"is invalid", [type: :integer, validation: :cast]}], data: #TweetBot.Accounts.User<>, valid?: false>}
     code: user = user_fixture()
     stacktrace:
       test/tweet_bot/accounts/accounts_test.exs:14: TweetBot.AccountsTest.user_fixture/1
       test/tweet_bot/accounts/accounts_test.exs:23: (test)



  2) test users update_user/2 with invalid data returns error changeset (TweetBot.AccountsTest)
     test/tweet_bot/accounts/accounts_test.exs:50
     ** (MatchError) no match of right hand side value: {:error, #Ecto.Changeset<action: :insert, changes: %{access_token: "some access_token"}, errors: [from_id: {"is invalid", [type: :integer, validation: :cast]}], data: #TweetBot.Accounts.User<>, valid?: false>}
     code: user = user_fixture()
     stacktrace:
       test/tweet_bot/accounts/accounts_test.exs:14: TweetBot.AccountsTest.user_fixture/1
       test/tweet_bot/accounts/accounts_test.exs:51: (test)

.

  3) test users update_user/2 with valid data updates the user (TweetBot.AccountsTest)
     test/tweet_bot/accounts/accounts_test.exs:42
     ** (MatchError) no match of right hand side value: {:error, #Ecto.Changeset<action: :insert, changes: %{access_token: "some access_token"}, errors: [from_id: {"is invalid", [type: :integer, validation: :cast]}], data: #TweetBot.Accounts.User<>, valid?: false>}
     code: user = user_fixture()
     stacktrace:
       test/tweet_bot/accounts/accounts_test.exs:14: TweetBot.AccountsTest.user_fixture/1
       test/tweet_bot/accounts/accounts_test.exs:43: (test)



  4) test users get_user!/1 returns the user with given id (TweetBot.AccountsTest)
     test/tweet_bot/accounts/accounts_test.exs:27
     ** (MatchError) no match of right hand side value: {:error, #Ecto.Changeset<action: :insert, changes: %{access_token: "some access_token"}, errors: [from_id: {"is invalid", [type: :integer, validation: :cast]}], data: #TweetBot.Accounts.User<>, valid?: false>}
     code: user = user_fixture()
     stacktrace:
       test/tweet_bot/accounts/accounts_test.exs:14: TweetBot.AccountsTest.user_fixture/1
       test/tweet_bot/accounts/accounts_test.exs:28: (test)



  5) test users create_user/1 with valid data creates a user (TweetBot.AccountsTest)
     test/tweet_bot/accounts/accounts_test.exs:32
     match (=) failed
     code:  assert {:ok, %User{} = user} = Accounts.create_user(@valid_attrs)
     right: {:error,
             #Ecto.Changeset<
               action: :insert,
               changes: %{access_token: "some access_token"},
               errors: [
                 from_id: {"is invalid", [type: :integer, validation: :cast]}
               ],
               data: #TweetBot.Accounts.User<>,
               valid?: false
             >}
     stacktrace:
       test/tweet_bot/accounts/accounts_test.exs:33: (test)



  6) test users delete_user/1 deletes the user (TweetBot.AccountsTest)
     test/tweet_bot/accounts/accounts_test.exs:56
     ** (MatchError) no match of right hand side value: {:error, #Ecto.Changeset<action: :insert, changes: %{access_token: "some access_token"}, errors: [from_id: {"is invalid", [type: :integer, validation: :cast]}], data: #TweetBot.Accounts.User<>, valid?: false>}
     code: user = user_fixture()
     stacktrace:
       test/tweet_bot/accounts/accounts_test.exs:14: TweetBot.AccountsTest.user_fixture/1
       test/tweet_bot/accounts/accounts_test.exs:57: (test)



  7) test users change_user/1 returns a user changeset (TweetBot.AccountsTest)
     test/tweet_bot/accounts/accounts_test.exs:62
     ** (MatchError) no match of right hand side value: {:error, #Ecto.Changeset<action: :insert, changes: %{access_token: "some access_token"}, errors: [from_id: {"is invalid", [type: :integer, validation: :cast]}], data: #TweetBot.Accounts.User<>, valid?: false>}
     code: user = user_fixture()
     stacktrace:
       test/tweet_bot/accounts/accounts_test.exs:14: TweetBot.AccountsTest.user_fixture/1
       test/tweet_bot/accounts/accounts_test.exs:63: (test)

.....

Finished in 0.2 seconds
15 tests, 7 failures

Randomized with seed 138456
```
不出所料，15 个测试有 7 个出错。

不过修复起来也很简单，打开 `accounts_test.exs` 文件，将 `from_id` 从字符串改为数值：

```elixir
-    @valid_attrs %{access_token: "some access_token", from_id: "some from_id"}
-    @update_attrs %{access_token: "some updated access_token", from_id: "some updated from_id"}
+    @valid_attrs %{access_token: "some access_token", from_id: 1}
+    @update_attrs %{access_token: "some updated access_token", from_id: 2}
     @invalid_attrs %{access_token: nil, from_id: nil}
 
     def user_fixture(attrs \\ %{}) do
@@ -32,7 +32,7 @@ defmodule TweetBot.AccountsTest do
     test "create_user/1 with valid data creates a user" do
       assert {:ok, %User{} = user} = Accounts.create_user(@valid_attrs)
       assert user.access_token == "some access_token"
-      assert user.from_id == "some from_id"
+      assert user.from_id == 1
     end
 
     test "create_user/1 with invalid data returns error changeset" do
@@ -44,7 +44,7 @@ defmodule TweetBot.AccountsTest do
       assert {:ok, user} = Accounts.update_user(user, @update_attrs)
       assert %User{} = user
       assert user.access_token == "some updated access_token"
-      assert user.from_id == "some updated from_id"
+      assert user.from_id == 2
     end
```
再运行 `mix test`，悉数通过。

## 优化代码

在添加上述 Plug 后，我们可以对 `twitter_controller.ex` 中的 `index` 动作做进一步优化：

```elixir
   plug :find_user
 
-  def index(conn, %{"message" => %{"from" => %{"id" => from_id}, "text" => text}}) do
-    case text do
-      "/start" ->
-        token = ExTwitter.request_token(URI.encode_www_form(TweetBotWeb.Router.Helpers.auth_url(conn, :callback) <> "?from_id=#{from_id}"))
-        {:ok, authenticate_url} = ExTwitter.authenticate_url(token.oauth_token)
-        sendMessage(from_id, "请点击链接登录您的 Twitter 账号授权：<a href='" <> authenticate_url <> "'>登录 Twitter</a>", parse_mode: "HTML")
-      _ -> sendMessage(from_id, "你好")
-    end
+  def index(conn, %{"message" => %{"text" => "/start"}}) do
+    sendMessage(conn.assigns.current_user, "已授权，请直接发送消息")
+    json(conn, %{})
+  end
+
+  def index(conn, _) do
     json(conn, %{})
   end
```
是了，这里展示的正是模式匹配的优美。我们可以在一个 controller 文件里写多个同名 `index` 动作，每个动作处理不同的参数 - 不必在一个巨大的 `index` 动作中又是 `if` `else` 又是 `case do` 了。