# 回复

服务器想要回复消息给用户的话，需要一个 telegram bot api 的 elixir 库，因为所需功能非常少，所以这里就用我以前写的一个简单的 [TelegramBot](https://github.com/chenxsan/TelegramBot) 库。

在 `mix.exs` 文件 `deps` 中新增 `{:telegram_bot, "~>0.1.0}`：

```
       {:gettext, "~> 0.11"},
-      {:cowboy, "~> 1.0"}
+      {:cowboy, "~> 1.0"},
+      {:telegram_bot, "~> 0.1.0"}
     ]
```

命令行下运行 `mix deps.get` 安装 `telegram_bot` 依赖。

## sendMessage

`TwitterController` 里的 `index` 动作在接收到 telegram 消息后，需要调用 `telegram_bot` 提供的 `sendMessage` 方法，回复消息给用户。

而调用 `telegram_bot` 的方法，需要先配置 telegram 的 token，打开 `dev.exs` 文件，在文件末尾新增内容如下：

```elixir
# Configures token for telegram bot
config :telegram_bot,
  token: System.get_env("TELEGRAM_TOKEN")
```
这样，telegram token 就可以从环境变量中读取。

命令行下配置 `TELEGRAM_TOKEN` 环境变量：

```sh
$ export TELEGRAM_TOKEN=''
```

注意，调整 `dev.exs` 后需要重启 Phoenix 服务器。

### 注意事项

因为 telegram 被墙，所以我还需要给终端设置代理，`telegram_bot` API 会自动读取环境变量中的代理设置：

```sh
$ export http_proxy=http://127.0.0.1:1087;export https_proxy=http://127.0.0.1:1087;
```

是的，在中国开发个程序就是要做这么多别国程序员觉得多余的事。

### 回复“你好”

上述准备工作完成后，就可以调整 `twitter_controller.ex` 中的代码：

```elixir
 defmodule TweetBotWeb.TwitterController do
   use TweetBotWeb, :controller
 
+  import TelegramBot
+
   def index(conn, %{"message" => %{"from" => %{"id" => from_id}, "text" => text}}) do
+    sendMessage(from_id, "你好")
     json conn, %{}
   end
 end
```
现在给测试用的发推机器人发送任何消息，都会收到“你好”的回复。