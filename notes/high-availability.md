# 高可用

Erlang 的一大亮点是高可用，但我目前部署的应用则非常脆弱，因为存在严重的[单点故障](https://en.wikipedia.org/wiki/Single_point_of_failure)。

先解决单点本身可能发生的故障：

1. 服务器重启时，CaddyServer 未能随之重启
2. 服务器重启时，Phoenix 应用未能随之重启
3. 每次重启应用，环境变量都要重新 `export`

第一个问题，Caddy 提供了几种[解决办法](https://github.com/mholt/caddy/wiki/Caddy-as-a-service-examples)，最简单的，是通过 [hook.service 插件](https://github.com/hacdias/caddy-service)。

来重新安装下 caddy：

```sh
$ curl https://getcaddy.com | bash -s personal hook.service,http.ipfilter,http.ratelimit
```
然后安装、启动 caddy service：

```sh
$ sudo caddy -service install -agree -email your-email@address.com -conf /home/ubuntu/Caddyfile
$ sudo caddy -service start
```
之后可以通过 `systemctl status Caddy` 查看 caddy 服务的状态。


第二个问题，我们同样要借助 [systemd](https://hexdocs.pm/distillery/guides/systemd.html)。

在 `/etc/systemd/system/` 下新建一个 `TweetBot.service`：

```
[Unit]
Description=TweetBot
After=network.target

[Service]
Type=forking
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/tweet_bot
EnvironmentFile=/etc/default/tweet_bot.env
ExecStart=/home/ubuntu/tweet_bot/bin/tweet_bot start
ExecStop=/home/ubuntu/tweet_bot/bin/tweet_bot stop
PIDFile=/home/ubuntu/tweet_bot/tweet_bot.pid
Restart=on-failure
RestartSec=5
Environment=LANG=en_US.UTF-8
Environment=PIDFILE=/home/ubuntu/tweet_bot/tweet_bot.pid
SyslogIdentifier=tweet_bot
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```
注意，在 service 里，我们的环境变量是从 `/etc/default/tweet_bot.env` 文件读取的，它的格式为：

```
PORT=4200
...
```

接着启动 TweetBot：

```sh
$ sudo systemctl daemon-reload
$ sudo systemctl enable TweetBot
$ sudo systemctl start TweetBot
```
启动完成后，可以通过 `systemctl status TweetBot` 查看状态。这样，我们就一举解决了开头罗列的 2、3 问题。

## Load balancer

上面我解决了单点本身可能故障的问题，然而该节点出问题的话，整个服务就不再可用。理想的情况，应该配置多个服务节点，组成 load balancer，然而，load balancer 太贵，所以暂时就不再折腾。

至此，笔记完成。
