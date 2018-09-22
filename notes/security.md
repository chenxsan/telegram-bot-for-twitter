# 关于安全

你看，只要你愿意，你就可以伪造一条 telegram 消息，然后 POST 到我的 webhook。

这一点，微信公众号要做得更好，因为你需要验证消息来源。

不过我们还是有些办法的。

我们从 [https://core.telegram.org/bots/webhooks](https://core.telegram.org/bots/webhooks) 文档里看到如下一句：

> Accepts incoming POSTs from 149.154.167.197-233 on port 443,80,88 or 8443. 

是了，我们可以考虑限定流量的来源。

telegram 还给了另一条[建议](https://core.telegram.org/bots/faq#how-can-i-make-sure-that-webhook-requests-are-coming-from-telegr)：

> If you‘d like to make sure that the Webhook request comes from Telegram, we recommend using a secret path in the URL you give us, e.g. www.example.com/your_token. Since nobody else knows your bot’s token, you can be pretty sure it's us.

它推荐我们使用一个隐藏的 webhook 路径，比如把 `/api/twitter` 换成 `/api/xljfdlsajflsdfjsaf` 这样。

## 数据安全

用户登录 Twitter 并授权后，我们得到用户的 `oauth_token` 与 `oauth_token_secret`。目前我们是明文保存这俩个数据，这意味着，数据库被人侵入的话，攻击者如果再拿到应用的 Consumer Key 与 Consumer Secret，就可以读写用户的 timeline - 当然，这种情况发生的概率非常低，因为我的数据库与应用程序跑在不同服务器上。另外，一旦发生攻击事件，用户可以在 [https://twitter.com/settings/applications](https://twitter.com/settings/applications) 里取消对此应用的授权，及时止损。

所以我暂时没有打算加密存储 `oauth_token` 及 `oauth_token_secret` - 直到有资料说服我为止。