# 保存用户数据

在上一节，我们已经获取到用户的如下数据：

1. `from_id`
2. `access_token`
3. `access_token_secret`

接下来就是将它们保存到数据库中。

不过有一个问题，`from_id` 与 `access_token` 其实分处两个请求中，我们如何在用户授权成功后获取到 `from_id` 值？

一个简单办法，是在传递 twitter 回调网址时一并将 `from_id` 传出。

打开 `twitter_controller.ex` 文件，修改代码如下：

```elixir
-        TweetBotWeb.Router.Helpers.auth_url(conn, :callback))
+        TweetBotWeb.Router.Helpers.auth_url(conn, :callback) <> "?from_id=#{from_id}")
```
测试发现，可行。

接着调整 `auth_controller.ex`，将授权成功后的自动发推去掉 - 我想没人希望出现这种乱发推的情况。

```elixir
 defmodule TweetBotWeb.AuthController do
   use TweetBotWeb, :controller
+  alias TweetBot.Accounts
 
-  def callback(conn, %{"oauth_token" => oauth_token, "oauth_verifier" => oauth_verifier}) do
+  def callback(conn, %{
+        "from_id" => from_id,
+        "oauth_token" => oauth_token,
+        "oauth_verifier" => oauth_verifier
+      }) do
     # 获取 access token
     {:ok, token} = ExTwitter.access_token(oauth_verifier, oauth_token)
 
-    ExTwitter.configure(
-      :process,
-      Enum.concat(
-        ExTwitter.Config.get_tuples(),
-        access_token: token.oauth_token,
-        access_token_secret: token.oauth_token_secret
-      )
-    )
-
-    ExTwitter.update("I just sign up telegram bot tweet_for_me_bot.")
-    text(conn, "授权成功，请关闭此页面")
+    case Accounts.create_user(%{
+           from_id: from_id,
+           access_token: token.oauth_token,
+           access_token_secret: token.oauth_token_secret
+         }) do
+      {:ok, _} -> text(conn, "授权成功，请关闭此页面")
+      {:error, _changeset} -> text(conn, "授权失败")
+    end
   end
 end
```
再跑一遍，在“授权成功”信息出现后，查看本地数据库 - 已成功插入数据。

那么，下次用户再发送 `/start` 时，我们就可以检查 `token` 是否已存在，再来决定是要求用户授权，还是提示用户直接发送消息。