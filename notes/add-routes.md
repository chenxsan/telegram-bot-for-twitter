# 路由

打开 `lib/tweet_bot_web/router.ex` 文件，添加上一节中尚未创建的路由：

```elixir
  scope "/api", TweetBotWeb do
    pipe_through(:api)
+   post("/twitter", TwitterController, :index)
  end
```
接着在 `lib/tweet_bot_web/controllers` 目录下新建控制器 `twitter_controller.ex`：

```elixir
defmodule TweetBotWeb.TwitterController do
  use TweetBotWeb, :controller

  def index(conn, _params) do
    json(conn, %{})
  end
end
```
现在只是响应一个 json 空对象。

## TwitterController

我们先要获取 telegram 用户的 id 及消息内容。将 `index` 动作调整如下：

```elixir
  def index(conn, %{"message" => %{"from" => %{"id" => from_id}, "text" => text}}) do
    json(conn, %{})
  end
```
这里利用[模式匹配](https://elixir-lang.org/getting-started/pattern-matching.html)提取用户 `id` 及 `text` 内容。

用户添加 telegram 发推机器人后 telegram 客户端会自动发起一个消息，这个消息的 `text` 内容是 `/start`。在收到这个消息后，`index` 要做几个判断：

1. 检查数据库中是否已经存在 `from_id` 数据，如果没有，表示用户未授权，此时应启动 twitter 的 OAuth 流程；
2. 如果数据库中存在 `from_id` 数据，说明用户已授权 - 提示用户直接发送消息。

我们需要在数据库中存储两个数据：

1. `from_id`
2. `access_token`

手写 Scheme？当然不，用 [mix tasks](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Context.html#content) 吧：

```sh
$ mix phx.gen.context Accounts User users from_id:string:unique access_token:string
* creating lib/tweet_bot/accounts/user.ex
* creating priv/repo/migrations/20180921014945_create_users.exs
* creating lib/tweet_bot/accounts/accounts.ex
* injecting lib/tweet_bot/accounts/accounts.ex
* creating test/tweet_bot/accounts/accounts_test.exs
* injecting test/tweet_bot/accounts/accounts_test.exs

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```
这里新建了一个 `Accounts` 上下文，以及 `User` 结构。

从上面生成的代码可以看到，Phoenix 命令还生成了 `accounts_test.exs`，运行 `mix test` 看看：

```sh
$ mix test
Generated tweet_bot app
...........

Finished in 0.2 seconds
11 tests, 0 failures

Randomized with seed 168024
```
Cool，悉数通过。此时再运行 `mix ecto.migrate` 创建表：

```sh
$ mix ecto.migrate
[info] == Running TweetBot.Repo.Migrations.CreateUsers.change/0 forward
[info] create table users
[info] create index users_from_id_index
[info] == Migrated in 0.0s
```

