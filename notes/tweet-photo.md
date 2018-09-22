# 发送图片

## Telegram 图片数据

我们给 telegram 机器人发送图片，webhook 会收到 [message](https://core.telegram.org/bots/api#message) 数据，其中有一个 `photo` 字段罗列了 telegram 支持的该图片的所有尺寸，它大概长这样：

```elixir
"photo" => [%{"file_id" => "AgADBQADI6gxG_qlmFUMyI1xrkLDad-o0zIABIuXxQXrM9uWjrIBAAEC", "file_size" => 1582, "height" => 76, "width" => 90}, %{"file_id" => "AgADBQADI6gxG_qlmFUMyI1xrkLDad-o0zIABJRMVi55JZ27j7IBAAEC", "file_size" => 16672, "height" => 270, "width" => 320}, %{"file_id" => "AgADBQADI6gxG_qlmFUMyI1xrkLDad-o0zIABPLMByqNSFYokLIBAAEC", "file_size" => 58871, "height" => 674, "width" => 800}, %{"file_id" => "AgADBQADI6gxG_qlmFUMyI1xrkLDad-o0zIABGV9HDHcMkzijbIBAAEC", "file_size" => 112278, "height" => 1078, "width" => 1280}]
```

因此我们要在 `twitter_controller.ex` 中新增一个 `index` 动作，专门处理这类情况：

```elixir
 def index(conn, %{"message" => %{"photo" => photo} = message}) do

 end
```
对我们来说，我们只要关心 `photo` 中最大的那张，其它尺寸不管：

```elixir
photo |> Enum.at(-1)
```
这样我们就取得了最大的一张图片。

接下来我们要下载图片，然后调用 ExTwitter 接口发布图片。

然而在下载图片前，我们得调用 `telegram_bot` 的 `getFile` 方法，让 telegram 提前准备我们要下载的图片。

## getFile

我们的代码这么写：

```elixir
  def index(conn, %{"message" => %{"photo" => photo} = message}) do
    case getFile(photo |> Enum.at(-1) |> Map.get("file_id")) do
      {:ok, file} ->
        %HTTPoison.Response{body: body} =
          HTTPoison.get!(
            "https://api.telegram.org/file/bot#{Application.get_env(:telegram_bot, :token)}/#{
              file |> Map.get("file_path")
            }",
            []
          )

        try do
          ExTwitter.update_with_media("", body)
        rescue
          e in ExTwitter.Error ->
            sendMessage(conn.assigns.current_user, "#{e.message}")
        end

      {:error, {_, reason}} ->
        sendMessage(conn.assigns.current_user, reason)
    end

    json(conn, %{})
  end
```
从 `photo` 获得最大尺寸的图片的 `file_id` 值后，我们调用 `getFile`，然后执行 `HTTPoison.get` 来下载图片，随后调用 `ExTwitter.update_with_media` 来发推。

你也许好奇为什么我可以在代码中直接使用 `HTTPoison` - 因为 `telegram_bot` 依赖中已经定义了。

但我们的代码中有个问题：上述代码只处理了单张图片不带 caption 的情况，还有单张图片带 caption、多张图片的情况。

### 单张图片 + Caption

我们可以再定义一个 `index` 动作来处理这种情况：

```elixir
# 单图，有 caption
def index(conn, %{"message" => %{"photo" => photo, "caption" => caption}}) do
  json(conn, %{})
end
```
但这样的话，函数体很大部分会重复。

最后我选择改造旧的 `index`：

```elixir
-  def index(conn, %{"message" => %{"photo" => photo}}) do
+  # 单图
+  def index(conn, %{"message" => %{"photo" => photo} = message}) do
+    caption = Map.get(message, "caption", "")
+
     case getFile(photo |> Enum.at(-1) |> Map.get("file_id")) do
       {:ok, file} ->
@@ -26,7 +27,7 @@ defmodule TweetBotWeb.TwitterController do
           )
 
         try do
-          ExTwitter.update_with_media("", body)
+          ExTwitter.update_with_media(caption, body)
```

## Telegram file

除开 `photo` 外，我们还可以以 `file` 的形式发送图片 - 匹别在于 `file` 的形式能够保留图片质量，而 `photo` 是会被压缩的。

我们以 `file` 形式发送一张 png 图片后，可以得到如下的数据结构：

```json
"document": {
    "file_name": "Screen Shot 2018-03-15 at 5.06.33 PM.png",
    "mime_type": "image/png",
    "thumb": {
        "file_id": "AAQFABNB9dQyAATCqwat-kKWDMEwAAIC",
        "file_size": 2695,
        "width": 86,
        "height": 90
    },
    "file_id": "BQADBQADFgAD-qWYVQL_5lHSA-xKAg",
    "file_size": 300198
}
```
我需要处理 `file` 形式发送的图片，包括 png、jpg、jpeg、gif，至于其它格式，比如 pdf 等，就不在我们考虑中了。

这一次，我们要新增一个 `index` 动作：

```elixir
# 处理 file 形式的图片
  def index(conn, %{
        "message" => %{"document" => %{"mime_type" => mime_type} = document} = message
      })
      when mime_type in ["image/png", "image/jpeg", "image/gif"] do
    caption = Map.get(message, "caption", "")
    case getFile(Map.get(document, "file_id")) do
      {:ok, file} ->
        %HTTPoison.Response{body: body} =
          HTTPoison.get!(
            "https://api.telegram.org/file/bot#{Application.get_env(:telegram_bot, :token)}/#{
              file |> Map.get("file_path")
            }",
            []
          )

        try do
          ExTwitter.update_with_media(caption, body)
        rescue
          e in ExTwitter.Error ->
            sendMessage(conn.assigns.current_user, "#{e.message}")
        end

      {:error, {_, reason}} ->
        sendMessage(conn.assigns.current_user, reason)
    end

    json(conn, %{})
  end
```

你可以看到，新增的 `index` 跟处理 `photo` 的 `index` 有大量的重复代码 - 不过且放一边，我们后面找时间优化它们。