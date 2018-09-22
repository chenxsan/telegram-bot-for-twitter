# 细节中藏着魔鬼

我们还有许多细节尚未考虑，下列罗列我现在想到的几点。

## 字符限制

我们知道 twitter 曾经有 140 个字符的限制，后面陆陆续续又开放了更多的字符。

所以，用户发送的消息超过 [twitter 字符限制](https://developer.twitter.com/en/docs/basics/counting-characters)时，我们要怎么办？

是在服务器端就做判断然后提示用户呢？还是不管不问假装没看到直接提交给 twitter api 由它来判断，我们只负责传话呢？

显然，twitter [官方库](https://github.com/twitter/twitter-text)中并不支持 Elixir 这样还比较小众的语言。

另外，我稍稍验证了下，目前中文限制是 140 个字符，英文是 280 个字符，其它语言的情况可能还更复杂。所以直接把用户消息提交给 twitter api 来判定是比较靠谱、也简单的。我们只需要把 twitter api 的错误响应返回给用户即可。

```elixir
-
-    ExTwitter.update(text)
+    try do
+      ExTwitter.update(text)
+    rescue
+      e in ExTwitter.Error -> sendMessage(conn.assigns.current_user, "#{e.message}")
+    end
     json(conn, %{})
```
至于成功发推的情况，就不回消息给用户了 - no news is good news。

## 图片等

除了文字外，telegram 还可以发送图片、文件、视频、音频，等等内容。

目前，我们还只处理了文本。其它类型要怎么办？提示用户？还是不管？

提示用户的话，我们很可能要撞上 telegram 的 [api 限制](https://core.telegram.org/bots/faq#my-bot-is-hitting-limits-how-do-i-avoid-this)。实际上，前面在超出 twitter 字符限制时，我们选择了提示用户，就已经有可能撞上 telegram 的 api 限制。所以应尽量避免给用户回复消息。

毕竟，Erlang 系统非常稳健，碰上照片这样程序未处理的问题，也不会像 Node.js 那样导致整个程序崩溃。

但我还是决定加入图片支持 - 毕竟，我挺经常在 twitter 上发图片。
