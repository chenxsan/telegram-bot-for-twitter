# 测试 `User`

老实讲，我不大喜欢写测试。

但我还是得说，测试非常重要。它们是我们修改代码的灯塔 - 没有它们，我们很可能会翻船。只是大部分项目活不过几个迭代 - 也就没多大必要写测试。

## user_test.exs

前一节里，我用 `mix phx.gen.context` 命令生成了几个文件，其中有 `accounts_test.exs`，但偏偏没有 `user_test.exs`，而在 Phoenix 1.3 以前，默认是有生成 `user_test.exs` 的 - 这是否意味着，Phoenix 1.3 以后我们不再需要给 Schema 写测试？我觉得这个就仁者见仁，智者见智了。

显然，我这里是要给 `User` 写测试。

针对 `User`，有两个要点需要测试：

1. `from_id` 必填
2. `from_id` 独一无二

在 `test/tweet_bot/accounts` 目录下新建 `user_test.exs` 文件，添加内容如下：

```elixir
defmodule TweetBot.UserTest do
  use TweetBot.DataCase

  alias TweetBot.Accounts.User
end
```
### 冒烟测试

在测试具体要点前，我们先写几个简单的冒烟测试。

在 `user_test.exs` 文件中新增测试如下：

```elixir
   alias TweetBot.Accounts.User
 
+  @valid_attrs %{from_id: "123456"}
+  @invalid_attrs %{from_id: nil}
+
+  test "changeset with valid attributes" do
+    changeset = User.changeset(%User{}, @valid_attrs)
+    assert changeset.valid?
+  end
+
+  test "changeset with invalid attributes" do
+    changeset = User.changeset(%User{}, @invalid_attrs)
+    refute changeset.valid?
+  end
```
运行 `mix test`：

```sh
$ mix test
..........

  1) test changeset with valid attributes (TweetBot.UserTest)
     test/tweet_bot/accounts/user_test.exs:9
     Expected truthy, got false
     code: assert changeset.valid?()
     stacktrace:
       test/tweet_bot/accounts/user_test.exs:11: (test)

..

Finished in 0.1 seconds
13 tests, 1 failure

Randomized with seed 481372
```
第一个测试报错。检查 `user.ex` 文件，我们看到如下代码：

```elixir
|> validate_required([:from_id, :access_token])
```
正是这一句导致测试失败 - 因为在我的设计中，`access_token` 一栏并非必填，而 `mix phx.gen` 命令在生成时默认 `access_token` 必填。所以我们要从中移去 `access_token`：

```elixir
     |> cast(attrs, [:from_id, :access_token])
-    |> validate_required([:from_id, :access_token])
+    |> validate_required([:from_id])
     |> unique_constraint(:from_id)
```
再运行 `mix test`：

```sh
$ mix test
Compiling 1 file (.ex)
.............

Finished in 0.1 seconds
13 tests, 0 failures

Randomized with seed 658072
```
测试悉数通过。

### 特性测试

冒烟测试通过后，我们再来写测试细节：

```elixir
+
+  test "from_id should be required" do
+    changeset = User.changeset(%User{}, @invalid_attrs)
+    assert %{from_id: ["不能留空"]} = errors_on(changeset)
+  end
+
+  test "from_id should be unique" do
+    changeset = User.changeset(%User{}, @valid_attrs)
+    assert Repo.insert!(changeset)
+    assert {:error, changeset} = Repo.insert(changeset)
+    assert %{from_id: ["已被占用"]} = errors_on(changeset)
+  end
```
再运行测试：
```sh
$ mix test
..........

  1) test from_id should be unique (TweetBot.UserTest)
     test/tweet_bot/accounts/user_test.exs:24
     match (=) failed
     code:  assert %{from_id: ["已被占用"]} = errors_on(changeset)
     right: %{from_id: ["has already been taken"]}
     stacktrace:
       test/tweet_bot/accounts/user_test.exs:28: (test)



  2) test from_id should be required (TweetBot.UserTest)
     test/tweet_bot/accounts/user_test.exs:19
     match (=) failed
     code:  assert %{from_id: ["不能留空"]} = errors_on(changeset)
     right: %{from_id: ["can't be blank"]}
     stacktrace:
       test/tweet_bot/accounts/user_test.exs:21: (test)

...

Finished in 0.1 seconds
15 tests, 2 failures

Randomized with seed 19240
```
由于消息不一致，所以新增的两个测试均报告错误。

我们来调整下 `user.ex` 文件，添加自定义消息：

```elixir
     |> cast(attrs, [:from_id, :access_token])
-    |> validate_required([:from_id])
-    |> unique_constraint(:from_id)
+    |> validate_required([:from_id], message: "不能留空")
+    |> unique_constraint(:from_id, message: "已被占用")
   end
```
再次运行测试：

```sh
mix test
Compiling 1 file (.ex)
...............

Finished in 0.1 seconds
15 tests, 0 failures

Randomized with seed 89151
```
悉数通过。

是了，这就是测试驱动开发。