# 测试

在前面几节，我给 `User` 结构写过测试，当时号称这是测试驱动。但随后新增的代码，不管是路由还是控制器或其它，均没有测试先行。这一节我们来亡羊补牢。

## 路由

我们已经知道，post `/start` 消息到 `/api/twitter` 接口有两种可能结果：

1. 用户未授权，返回 OAuth 授权链接
2. 用户已授权，提示用户直接发送消息

但未授权的情况下，ExTwitter 需要与 twitter api 通信，我们的测试将依赖网络状况，这是应避免的。

我们来优化下代码，让 `twitter_controller.ex` 代码便于测试。

首先在 `lib/tweet_bot_web/controllers` 目录下新增一个 `twitter_api.ex` 文件：

```elixir
defmodule TwitterAPI do

  def request_token(redirect_url \\ nil) do
    ExTwitter.request_token(redirect_url)
  end

  def authenticate_url(token) do
    ExTwitter.authenticate_url(token)
  end
end
```
它很简单，就是 ExTwitter 的 API 的再封装，之所以要再度封装，主要是方便我们后面的测试。

接着，我们在 `config.exs` 里给应用定义一个环境变量 `twitter_api`：

```elixir
config :tweet_bot,
  twitter_api: TwitterAPI
```
这样我们就可以在 `twitter_controller.ex` 里读取并调用它：

```elixir
@twitter_api Application.get_env(:tweet_bot, :twitter_api)
```
然后将 `twitter_controller.ex` 中的 `get_twitter_oauth` 函数中的 ExTwitter 替换为 `@twitter_api`：

```elixir
defp get_twitter_oauth(conn, from_id) do
    token =
      @twitter_api.request_token(
        URI.encode_www_form(
          TweetBotWeb.Router.Helpers.auth_url(conn, :callback) <> "?from_id=#{from_id}"
        )
      )

    {:ok, authenticate_url} = @twitter_api.authenticate_url(token.oauth_token)
```
这一切改造都是为了方便测试。

那么，要如何测试？我们来试试 [`Mox`](https://hexdocs.pm/mox/Mox.html)。

Mox 有几条原则，其中一条说：

> mocks 应该基于行为（behaviours）

Elixir 下，行为定义的是接口，而我们要测试的代码与它们的 mock 均是行为的一种实现。

复杂？有点。

我们先来定义个 `Twitter` 行为，在 `lib/tweet_bot_web/controllers` 目录下新建一个 `twitter.ex` 文件：

```elixir
defmodule Twitter do
  @callback request_token(String.t()) :: map()
  @callback authenticate_url(String.t()) :: {:ok, String.t()} | {:error, String.t()}
end
```
然后调整 `twitter_api.ex` 文件，新增一行：

```elixir
@behaviour Twitter
```
这样 `TwitterAPI` 就是 `Twitter` 行为的一个具体实现了。

我们的 Mock 将同样是 `Twitter` 的一个实现。

在 `test/support` 目录下新建 `mocks.ex` 文件：

```elixir
Mox.defmock(TwitterMock, for: Twitter)
```
接着，在 `test/tweet_bot_web/controllers` 目录下新增 `twitter_controller_test.exs` 文件：

```elixir
defmodule TweetBotWeb.TwitterControllerTest do
  use TweetBotWeb.ConnCase
  import Mox

  setup :verify_on_exit!

  @valid_message %{
    "message" => %{
      "from" => %{
        "id" => 123
      },
      "text" => "/start"
    }
  }

  test "POST /api/twitter with /start first time", %{conn: conn} do
    TwitterMock
    |> expect(:request_token, fn _ -> %{oauth_token: ""} end)
    |> expect(:authenticate_url, fn _ -> {:ok, "https://blog.zfanw.com"} end)

    conn = post(conn, "/api/twitter", @valid_message)

    assert json_response(conn, 200) == %{
             "chat_id" => 123,
             "method" => "sendMessage",
             "parse_mode" => "HTML",
             "text" => "请点击链接登录您的 Twitter 账号进行授权：<a href='https://blog.zfanw.com'>登录 Twitter</a>"
           }
  end
end
```
大部分代码是参照 Mox 文档写的，`TwitterMock` 的具体实现是通过 `expect` 实现的。

那么，我要如何保证 `twitter_controller.ex` 代码在遇到 `@twitter_api` 时调用 `TwitterMock` 而不是 `TwitterAPI`？很简单，我们在 `test.exs` 里覆盖 `config.exs` 中定义的 `twitter_api` 环境变量：

```elixir
config :tweet_bot,
  twitter_api: TwitterMock
```
就这样。

运行 `mix test`，测试悉数通过。

同理，我们可以测试其它 POST /api/twitter 的情况。
