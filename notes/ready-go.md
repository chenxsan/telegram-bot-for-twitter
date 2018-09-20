# 准备工作

我的操作系统是 macOS，使用 [homebrew](https://brew.sh/) 命令安装 Elixir 是最简单的，`brew install elixir`，该命令会同时安装 Erlang。

Elixir 及 Erlang 的版本号可以通过命令 `mix hex.info` 查看：

```sh
$ mix hex.info
Hex:    0.18.1
Elixir: 1.7.3
OTP:    21.0.9

Built with: Elixir 1.6.6 and OTP 19.3
```

安装好 Elixir、Erlang 后，运行 mix 命令安装 Phoenix：

```sh
$ mix archive.install https://github.com/phoenixframework/archives/raw/master/phx_new.ez
```

`mix phx.new --version` 可以查看当前安装的 Phoenix 版本号：

```sh
$ mix phx.new --version
Phoenix v1.3.4
```
至于 Node.js - 我作为一个专职前端开发，当然是早已安装。

## 初始化项目

一切准备就绪后，执行 `mix phx.new` 命令初始化 Phoenix 项目：

```sh
$ mix phx.new tweet_bot
```
默认情况下，Phoenix 使用 PostgreSQL 数据库，如果你想使用 MySQL，请在命令行下指定 ` --database mysql`。

项目初始化完成，会在命令行中看到如下提示：

```
We are all set! Go into your application by running:

    $ cd tweet_bot

Then configure your database in config/dev.exs and run:

    $ mix ecto.create

Start your Phoenix app with:

    $ mix phx.server

You can also run your app inside IEx (Interactive Elixir) as:

    $ iex -S mix phx.server
```
按提示操作，就能在 http://0.0.0.0:4000 上启动开发服务器。注意，Phoenix 默认使用 `root` 账号连接本地 MySQL 数据库，且密码为空 - 如果本地 MySQL 数据库用户不是 `root` 或密码不为空，则需要调整 `dev.exs` 中的配置项。

## 创建 telegram bot

具体创建过程就不说了，创建出来的 telegram 机器人链接是 [http://t.me/tweet_for_me_bot](http://t.me/tweet_for_me_bot) - 当然，现在它什么都不会。

在创建 telegram 机器人过程中会获得一串 `token`，后面会用这串 `token` 来设置一个 [webhook](https://core.telegram.org/bots/api#setwebhook) - 这样 telegram 会将机器人收到的消息全部转发到我的 webhook。