# 与 Twitter 接口通信

首先访问 [https://apps.twitter.com](https://apps.twitter.com) 新建一个 app，这样就有了：

1. Consumer Key
2. Consumer Secret

记得需要配置 `Callback URLs` - 比如我后面将新建一个 `/auth_callback` 路由用于回调，则将 `Callback URLs` 设置为 `http://localhost:4000/auth_callback`。

接下来与 twitter 的一切通信都交给 [https://github.com/parroty/extwitter](https://github.com/parroty/extwitter) 库。

`extwitter` 的具体安装步骤这里就略过不提了。

安装完 `extwitter` 后，按说明在 `dev.exs` 添加如下配置（记得要重启 Phoenix）：

```elixir
+
+# Configures extwitter oauth
+config :extwitter, :oauth, [
+  consumer_key: System.get_env("TWITTER_CONSUMER_KEY"),
+  consumer_secret: System.get_env("TWITTER_CONSUMER_SECRET"),
+  access_token: "",
+  access_token_secret: ""
+]
```
我们从环境变量中读取 `consumer_key` 与 `consumer_secret` 的值，`access_token` 与 `access_token_secret` 值暂时留空，后面再动态设置。

不过等一等，`access_token_secret`？我在 `User` 结构中可是只定义了 `access_token`。

显然，我们需要在 `User` 结构中新增 `access_token_secret` 字段。

## mix ecto.gen.migration

我们要借助 [`mix ecto.gen.migration`](https://hexdocs.pm/phoenix/phoenix_mix_tasks.html#ecto-specific-mix-tasks)。

在命令行下执行：

```sh
$ mix ecto.gen.migration add_access_token_secret_to_users
Generated tweet_bot app
* creating priv/repo/migrations
* creating priv/repo/migrations/20180921113504_add_access_token_secret_to_users.exs
```
打开新建的文件，内容如下：

```elixir
defmodule TweetBot.Repo.Migrations.AddAccessTokenSecretToUsers do
  use Ecto.Migration

  def change do

  end
end
```
调整如下：

```
   def change do
-    
+    alter table(:users) do
+      add(:access_token_secret, :string)
+    end
   end
```
此外，我们还需要调整 `user.ex`：

```elixir
 defmodule TweetBot.Accounts.User do
   use Ecto.Schema
   import Ecto.Changeset
 
   schema "users" do
     field(:access_token, :string)
+    field(:access_token_secret, :string)
     field(:from_id, :string)
 
     timestamps()
   end
 
   @doc false
   def changeset(user, attrs) do
     user
-    |> cast(attrs, [:from_id, :access_token])
+    |> cast(attrs, [:from_id, :access_token, :access_token_secret])
     |> validate_required([:from_id], message: "不能留空")
     |> unique_constraint(:from_id, message: "已被占用")
   end
 end
```
因为新增的 `access_token_secret` 并非必填项，所以对我们旧有的测试没有影响。

现在运行 `mix ecto.migrate` 来让上述修改生效。

## 回调

再回到 [twitter OAuth 流程](https://dev.twitter.com/web/sign-in/implementing)，我们需要一个回调地址，这样用户登录后，twitter 会跳到该回调 - 并且携带 `oauth_token` 及 `oauth_verifier`，接着我们再提交这两个参数去换取 `access_token` 及 `access_token_secret`。

我们需要在 `router.ex` 中新增一个路由：

```elixir
   scope "/", TweetBotWeb do
     pipe_through :browser # Use the default browser stack

     get("/", PageController, :index)
+    get("/auth_callback", AuthController, :callback)
   end
```
接着创建 `lib/tweet_bot_web/controllers/auth_controller.ex` 文件：

```elixir
+defmodule TweetBotWeb.AuthController do
+  use TweetBotWeb, :controller
+
+  def callback(conn, _params) do
+  end
+end
```
`callback` 目前留空。

## 启动 OAuth

我们启动 OAuth 流程的时机是在接收到用户发来 `/start`。所以让我们回到 `twitter_controller.ex` 中，调整代码如下：

```elixir
   def index(conn, %{"message" => %{"from" => %{"id" => from_id}, "text" => text}}) do
-    sendMessage(from_id, "你好")
+    case text do
+      "/start" ->
+        token =
+          ExTwitter.request_token(
+            URI.encode_www_form(TweetBotWeb.Router.Helpers.auth_url(conn, :callback))
+          )
+
+        {:ok, authenticate_url} = ExTwitter.authenticate_url(token.oauth_token)
+
+        sendMessage(
+          from_id,
+          "请点击链接登录您的 Twitter 账号进行授权：<a href='" <> authenticate_url <> "'>登录 Twitter</a>",
+          parse_mode: "HTML"
+        )
+
+      _ ->
+        sendMessage(from_id, "你好")
+    end
+
     json(conn, %{})
   end
```
尝试给测试机器发送 `/start`，好一会儿，开发服务器下报告错误：

```sh
[error] #PID<0.474.0> running TweetBotWeb.Endpoint terminated
Request: POST /api/twitter
** (exit) an exception was raised:
    ** (MatchError) no match of right hand side value: {:error, {:failed_connect, [{:to_address, {'api.twitter.com', 443}}, {:inet, [:inet], :etimedout}]}}
        (extwitter) lib/extwitter/api/auth.ex:10: ExTwitter.API.Auth.request_token/1
        (tweet_bot) lib/tweet_bot_web/controllers/twitter_controller.ex:9: TweetBotWeb.TwitterController.index/2
        (tweet_bot) lib/tweet_bot_web/controllers/twitter_controller.ex:1: TweetBotWeb.TwitterController.action/2
        (tweet_bot) lib/tweet_bot_web/controllers/twitter_controller.ex:1: TweetBotWeb.TwitterController.phoenix_controller_pipeline/2
        (tweet_bot) lib/tweet_bot_web/endpoint.ex:1: TweetBotWeb.Endpoint.instrument/4
        (phoenix) lib/phoenix/router.ex:278: Phoenix.Router.__call__/1
        (tweet_bot) lib/tweet_bot_web/endpoint.ex:1: TweetBotWeb.Endpoint.plug_builder_call/2
        (tweet_bot) lib/plug/debugger.ex:102: TweetBotWeb.Endpoint."call (overridable 3)"/2
        (tweet_bot) lib/tweet_bot_web/endpoint.ex:1: TweetBotWeb.Endpoint.call/2
        (plug) lib/plug/adapters/cowboy/handler.ex:16: Plug.Adapters.Cowboy.Handler.upgrade/4
        (cowboy) /Users/sam/Documents/githubRepos/tweet_bot/deps/cowboy/src/cowboy_protocol.erl:442: :cowboy_protocol.execute/4
```
是了，`extwitter` 要与 twitter 通信，同样需要配置代理。打开 `dev.exs` 文件，新增如下内容：

```elixir
+]
+
+# Configures extwitter proxy
+config :extwitter, :proxy, [
+  server: "127.0.0.1",
+  port: 1087
 ]
```
重启开发服务器。再发送 `/start` 给机器人 - 收到登录链接了。

不过且慢点击登录链接。在点击前，我们还需要填充 `auth_controller.ex` 中的 `callback`：

```elixir
 
-  def callback(conn, _params) do
+  def callback(conn, %{"oauth_token" => oauth_token, "oauth_verifier" => oauth_verifier}) do
+    # 获取 access token
+    {:ok, token} = ExTwitter.access_token(oauth_verifier, oauth_token)
+    IO.inspect(token)
+    text(conn, "授权成功，请关闭此页面")
   end
```
跑一遍流程就会发现，我们已经成功获取到 `access_token` 与 `access_token_secret` 了 - 只不过，响应中的名称与我们预想中的不一样，一个是 `oauth_token`，一个是 `oauth_token_secret`，拿到这俩个数据后，我们就可以以用户的身份发推了：

```elixir
     {:ok, token} = ExTwitter.access_token(oauth_verifier, oauth_token)
-    IO.inspect(token)
+    ExTwitter.configure(
+      :process,
+      Enum.concat(
+        ExTwitter.Config.get_tuples,
+        [ access_token: token.oauth_token,
+          access_token_secret: token.oauth_token_secret ]
+      )
+    )
+    ExTwitter.update("I just sign up telegram bot tweet_for_me_bot.")
     text(conn, "授权成功，请关闭此页面")
```
发送 `/start` 给机器人，点击返回的链接，授权，查看 twitter 主页，有了：`I just sign up telegram bot tweet_for_me_bot.`。