# 部署 Phoenix Framework

据我所知，Phoenix 项目的部署方案有俩种：

1. [Phoenix 文档](https://hexdocs.pm/phoenix/deployment.html#content)中介绍的，将源代码推送到生产环境，安装依赖后运行 `MIX_ENV=prod mix phx.server`
2. 使用 [`distillery`](https://github.com/bitwalker/distillery) 构建 Erlang/OTP 发行包，然后部署发行包

第一种方案直观、简单，与开发环境的体验一致。然而第二种方案才是我们应该使用的部署方案，因为能够享有 OTP 的一切好处，但过程并不简单，至少目前是这样。

这里聊的是第二种方案。

## 安装 distillery

在 `mix.exs` 文件中新增 `distillery` 依赖如下：

```elixir
+      {:distillery, "~> 2.0"},
     ]
   end
```

然后运行 `mix deps.get` 安装 `distillery`。

安装完 `distillery` 后，运行 `mix release.init` 来初始化构建：

```sh
$ mix release.init
...
An example config file has been placed in rel/config.exs, review it,
make edits as needed/desired, and then run `mix release` to build the release
```

`mix release.init` 命令在 `rel` 目录下生成 `config.exs` 文件，稍后我们要做些调整。

## 配置 prod.exs

我们曾在 `dev.exs` 里新增过 `telegram_bot` 的 `token`：

```elixir
# Configures token for telegram bot
config :telegram_bot,
  token: System.get_env("TELEGRAM_TOKEN")
```

同样地，我们需要在 `prod.exs` 文件中新增：

```elixir
# Configures token for telegram bot
config :telegram_bot,
  token: System.get_env("TELEGRAM_TOKEN")
```

为什么不是在 `prod.secret.exs` 里新增？这是因为 `prod.secret.exs` 里存储的是明文的隐私内容，而 `System.get_env("TELEGRAM_TOKEN")` 并非隐私内容，就没必要放入 `prod.secret.exs` 里。

此外，我们还需要在 `prod.exs` 里配置 twitter 的 `consumer_key`、`consumer_secret`：

```elixir
# Configures extwitter oauth
config :extwitter, :oauth,
  consumer_key: System.get_env("TWITTER_CONSUMER_KEY"),
  consumer_secret: System.get_env("TWITTER_CONSUMER_SECRET")
```

至于 `prod.secret.exs` 中的其它配置，我们均调整为从环境变量中读取：

```elixir
config :tweet_bot, TweetBotWeb.Endpoint, secret_key_base: System.get_env("SECRET_KEY_BASE")

# Configure your database
config :tweet_bot, TweetBot.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: System.get_env("DATABASE_USER"),
  password: System.get_env("DATABASE_PASS"),
  database: System.get_env("DATABASE_NAME"),
  hostname: System.get_env("DATABASE_HOST"),
  pool_size: 15
```

不过这样的话，`prod.secret.exs` 就没有存在意义了，因此，我们将它的内容迁移至 `prod.exs` 中，并且删掉 `prod.exs` 的最末几行：

```elixir
- # Finally import the config/prod.secret.exs
- # which should be versioned separately.
- import_config "prod.secret.exs"
```

但我们有一个新问题，distillery 在构建时，`System.get_env("TELEGRAM_TOKEN")` 这样的动态取值变会成静态的 - 即哪儿构建，哪儿取值，而不是我们预想的从生产环境中动态读取。

Distillery 从 2.0 版本开始，提供了 [Config providers](https://hexdocs.pm/distillery/config/runtime.html#config-providers) 来解决这个问题。Config providers 能够在发行包启动前动态读取配置，并将结果推送入应用环境中。

怎么用？很简单，我们前面运行 `mix release.init` 时，根目录下生成了 `rel/config.exs` 文件，其中有 `release :tweet_bot do` 一段代码，我们在函数中新增如下代码：

```elixir
  set(
    config_providers: [
      {Mix.Releases.Config.Providers.Elixir, ["${RELEASE_ROOT_DIR}/etc/config.exs"]}
    ]
  )

  set(
    overlays: [
      {:copy, "config/prod.exs", "etc/config.exs"}
    ]
  )
```

`overlays` 表示将 `config` 目录下的 `prod.exs` 拷贝至 `etc/config.exs` 位置，而 `config_providers` 则指定 Config providers 从何处读取配置。

此外，我们还需要针对 Phoenix [调整 `prod.exs` 里的一些配置](https://hexdocs.pm/distillery/guides/phoenix_walkthrough.html)：

```elixir
 config :tweet_bot, TweetBotWeb.Endpoint,
-  load_from_system_env: true,
-  url: [host: "example.com", port: 80],
-  cache_static_manifest: "priv/static/cache_manifest.json"
+  http: [port: {:system, "PORT"}],
+  url: [host: "localhost", port: {:system, "PORT"}],
+  cache_static_manifest: "priv/static/cache_manifest.json",
+  server: true,
+  root: ".",
+  version: Application.spec(:tweet_bot, :vsn)
```

注意，应用绑定的端口同样是从生产环境变量 `PORT` 中读取。

## 初始化数据库

我们在开发环境中可以执行 `mix ecto.create` 来创建数据库，并通过 `mix ecto.migrate` 来初始化数据库表，但 distillery 构建后，mix 不再存在，所以开发环境中可行的方案都不再可行。

distillery 另有方案来[初始化数据库及数据库表](https://hexdocs.pm/distillery/guides/running_migrations.html)。

在 `lib` 目录下新建一个 `release_tasks.ex` 文件，内容如下：

```elixir
defmodule TweetBot.ReleaseTasks do
  @start_apps [
    :crypto,
    :ssl,
    :postgrex,
    :ecto
  ]

  @repos Application.get_env(:tweet_bot, :ecto_repos, [])

  def migrate(_argv) do
    start_services()

    run_migrations()

    stop_services()
  end

  def seed(_argv) do
    start_services()

    run_migrations()

    run_seeds()

    stop_services()
  end

  defp start_services do
    IO.puts("Starting dependencies..")
    # Start apps necessary for executing migrations
    Enum.each(@start_apps, &Application.ensure_all_started/1)

    # Start the Repo(s) for app
    IO.puts("Starting repos..")
    Enum.each(@repos, & &1.start_link(pool_size: 1))
  end

  defp stop_services do
    IO.puts("Success!")
    :init.stop()
  end

  defp run_migrations do
    Enum.each(@repos, &run_migrations_for/1)
  end

  defp run_migrations_for(repo) do
    app = Keyword.get(repo.config, :otp_app)
    IO.puts("Running migrations for #{app}")
    migrations_path = priv_path_for(repo, "migrations")
    Ecto.Migrator.run(repo, migrations_path, :up, all: true)
  end

  defp run_seeds do
    Enum.each(@repos, &run_seeds_for/1)
  end

  defp run_seeds_for(repo) do
    # Run the seed script if it exists
    seed_script = priv_path_for(repo, "seeds.exs")

    if File.exists?(seed_script) do
      IO.puts("Running seed script..")
      Code.eval_file(seed_script)
    end
  end

  defp priv_path_for(repo, filename) do
    app = Keyword.get(repo.config, :otp_app)

    repo_underscore =
      repo
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    priv_dir = "#{:code.priv_dir(app)}"

    Path.join([priv_dir, repo_underscore, filename])
  end
end
```

然后在 `rel/commands` 目录下新建 `migrate.sh`：

```sh
#!/bin/sh

release_ctl eval --mfa "TweetBot.ReleaseTasks.migrate/1" --argv -- "$@"
```

`"$@"` 表示将命令行参数全部传递给 `TweetBot.ReleaseTasks.migrate/1` 函数。

再新建一个 `seed.sh` 文件：

```sh
#!/bin/sh

release_ctl eval --mfa "TweetBot.ReleaseTasks.seed/1" --argv -- "$@"
```

最后调整 `rel/config.exs`，新增 `commands`：

```elixir
release :tweet_bot do
+ set commands: [
+   migrate: "rel/commands/migrate.sh",
+   seed: "rel/commands/seed.sh"
+ ]
end
```

这样我们在应用部署到生产环境后，就可以执行 `bin/tweet_bot migrate` 来初始化数据库表，`bin/tweet_bot seed` 来填充数据。

但我希望 migrate 与 seed 过程能够自动化，而不是启动应用后手动执行。Distillery 提供了 hook 来解决这个问题。

在 `rel/hooks` 目录下新建 `pre_start` 目录，并在 `pre_start` 目录下创建一个 `prepare` 文件，内容如下：

```sh
$RELEASE_ROOT_DIR/bin/tweet_bot migrate

$RELEASE_ROOT_DIR/bin/tweet_bot seed
```

再次调整 `rel/config.exs` 文件，新增：

```elixir
  set(
    overlays: [
      {:copy, "config/prod.exs", "etc/config.exs"}
    ]
  )
+ set(pre_start_hooks: "rel/hooks/pre_start")
```
这样应用在启动前会自动执行 migrate 与 seed 命令。

## 构建

在完成以上配置后，我们终于可以开始构建 Phoenix 程序。

运行 `MIX_ENV=prod mix release` 试试：

```sh
$ MIX_ENV=prod mix release
==> Assembling release..
==> Building release tweet_bot:0.0.1 using environment prod
==> Including ERTS 10.0.8 from /usr/local/Cellar/erlang/21.0.9/lib/erlang/erts-10.0.8
==> Packaging release..
Release successfully built!
To start the release you have built, you can use one of the following tasks:

    # start a shell, like 'iex -S mix'
    > _build/prod/rel/tweet_bot/bin/tweet_bot console

    # start in the foreground, like 'mix run --no-halt'
    > _build/prod/rel/tweet_bot/bin/tweet_bot foreground

    # start in the background, must be stopped with the 'stop' command
    > _build/prod/rel/tweet_bot/bin/tweet_bot start

If you started a release elsewhere, and wish to connect to it:

    # connects a local shell to the running node
    > _build/prod/rel/tweet_bot/bin/tweet_bot remote_console

    # connects directly to the running node's console
    > _build/prod/rel/tweet_bot/bin/tweet_bot attach

For a complete listing of commands and their use:

    > _build/prod/rel/tweet_bot/bin/tweet_bot help
```

构建成功。在设置好必需的环境变量后运行 `_build/prod/rel/tweet_bot/bin/tweet_bot console` 也没有问题。

但这只是本地构建。我在 macOS 系统上构建的发行包不能运行在生产环境系统中（Linux），因为不同系统下 Erlang 运行时（Erlang Runtime System）不一样。

我们有三种方案：

1. 本地构建时设定 `include_erts: false`，发行包里不再打包 ERTS，由生产环境自行安装 ERTS
2. 在本地交叉编译面向生产环境的 ERTS，并在构建时设定 `include_erts: "path/to/cross/compiled/erts"`
3. 在与生产环境类似的构建环境中构建发行包

我倾向于第 3 种方案。我可以新建一台服务器专门用于构建 - 但还有一个我看来更为简便、也更节省的方案：在 Docker 中构建。

### Docker 中构建 Phoenix 应用

因为我的程序最终将部署到 Ubuntu 16.04 系统，所以我需要准备一个基于 Ubuntu 16.04 的 [docker image](https://hub.docker.com/r/chenxsan/elixir-ubuntu/)，其中已安装好 Erlang 及 Elixir 等构建 Phoenix 所需的依赖。

参考 [Distillery 文档](https://hexdocs.pm/distillery/guides/building_in_docker.html#building-releases)在项目根目录新建一个 `bin` 文件夹，并在 `bin` 目录下新建 `build.sh` 文件，注意要执行 `chmod +x bin/build.sh` 让它可执行：

```sh
#!/usr/bin/env bash

set -e

cd /opt/build

APP_NAME="$(grep 'app:' mix.exs | sed -e 's/\[//g' -e 's/ //g' -e 's/app://' -e 's/[:,]//g')"
APP_VSN="$(grep 'version:' mix.exs | cut -d '"' -f2)"

mkdir -p /opt/build/rel/artifacts

export MIX_ENV=prod

# Fetch deps and compile
mix deps.get --only prod
# Run an explicit clean to remove any build artifacts from the host
mix do clean, compile --force
cd ./assets
npm install
npm run deploy
cd ..
mix phx.digest
# Build the release
mix release --env=prod
# Copy tarball to output
cp "_build/prod/rel/$APP_NAME/releases/$APP_VSN/$APP_NAME.tar.gz" rel/artifacts/"$APP_NAME-$APP_VSN.tar.gz"

exit 0
```

之后运行：

```sh
$ docker run -v $(pwd):/opt/build --rm -it chenxsan/elixir-ubuntu:latest /opt/build/bin/build.sh
```

之后我们就得到 `tweet_bot.tar.gz` 压缩包。

接下来是部署 `tweet_bot.tar.gz`。

## 搭建生产环境

我们可借助 Terraform、Ansible 一类运维工具准备生产环境，但这里不打算谈这类工具的使用，因为会增加笔记的复杂度。

我们创建一台安装了 Ubuntu 16.04 的服务器，然后在服务器上安装 [Caddy](https://caddyserver.com)：

```sh
$ CADDY_TELEMETRY=on curl https://getcaddy.com | bash -s personal http.ipfilter,http.ratelimit
```

之所以选择 Caddy 而不是 Nginx、Apache，是因为我不想折腾 Let's Encrypt。

## 启动

在启动程序前，我们需要事先创建生产环境数据库，并且配置以下环境变量：

1. PORT
2. TELEGRAM_TOKEN
3. TWITTER_CONSUMER_KEY
4. TWITTER_CONSUMER_SECRET
5. SECRET_KEY_BASE
6. DATABASE_USER
7. DATABASE_PASS
8. DATABASE_NAME
9. DATABASE_HOST

一切准备完后将 tweet_bot.tar.gz 文件上传到服务器并解压，之后执行：

```sh
$ PORT=4200 bin/tweet_bot start
```

成功了，我们现在已经可以通过 ip:4200 来访问 Phoenix 的默认页面。

## 配置 Caddy

新建一个 `Caddyfile`，文件内容如下：

```Caddyfile
https://tweetbot.zfanw.com {
  proxy / localhost:4200
  ipfilter /api/twitter {
    rule allow
    ip 149.154.167.197/32 149.154.167.198/31 149.154.167.200/29 149.154.167.208/28 149.154.167.224/29 149.154.167.232/31
  }
}
```

然后启动 caddy：

```
$ caddy -conf ./Caddyfile
```
但我们会看到如下警示：

> WARNING: File descriptor limit 1024 is too low for production servers. At least 8192 is recommended. Fix with "ulimit -n 8192"

解决办法很简单，我们可以在运行 `caddy` 前运行 `ulimit -n 8192`，但这只是临时性的。要让它永久生效，我们需要调整 `/etc/security/limits.conf`，在末尾新增两行：

```conf
* soft nofile 20000
* hard nofile 20000
```
之后重新连接服务器，并执行 `caddy -conf ./Caddyfile`。

## 设定 webhook

最后一步是设定 telegram 的 webhook。

## 验证

部署完成后，验证发推机器人发现一个问题：生产环境的 OAuth 回调地址同样是 `localhost:4000/auth_callback`

这个问题非常好解决，调整 `prod.exs` 中的 `url` 即可：

```elixir
   http: [port: {:system, "PORT"}],
-  url: [host: "localhost", port: {:system, "PORT"}],
+  url: [scheme: "https", host: "tweetbot.zfanw.com"],
   cache_static_manifest: "priv/static/cache_manifest.json",
```

这样，我们就完成了发推机器人的部署。

