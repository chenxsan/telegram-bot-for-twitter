# 发推

我们不妨把 `/start` 命令以外的文本全部认为是用户要发送的推文。

改造 `twitter_controller.ex` 如下：

```elixir
-  def index(conn, _) do
+  def index(conn, %{"message" => %{"text" => text}}) do
+    # 读取用户 token
+    user = Accounts.get_user_by_from_id!(conn.assigns.current_user)
+
+    ExTwitter.configure(
+      :process,
+      Enum.concat(
+        ExTwitter.Config.get_tuples(),
+        access_token: user.access_token,
+        access_token_secret: user.access_token_secret
+      )
+    )
+
+    ExTwitter.update(text)
     json(conn, %{})
   end
 end
```
我们从 `conn.assigns` 中读取 `current_user` 数据，然后动态配置 ExTwitter 的 `access_token` 及 `access_token_secret`，最后发送推文。

显然会报错，因为我们调用 `TweetBot.Accounts.get_user_by_from_id!` 方法 - 我们还没有定义过这个方法。

打开 `accounts.ex` 文件添加如下方法：

```elixir
+  def get_user_by_from_id!(from_id) do
+    Repo.get_by!(User, from_id: from_id)
+  end
```

好了，现在给机器人发送内容，已经可以发送到 twitter 了。