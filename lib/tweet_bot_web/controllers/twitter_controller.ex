defmodule TweetBotWeb.TwitterController do
  use TweetBotWeb, :controller

  import TelegramBot
  alias TweetBot.Accounts
  plug(:find_user)
  plug(:configure_extwitter)
  action_fallback(FallbackController)

  defp find_user(conn, _) do
    %{"message" => %{"from" => %{"id" => from_id}}} = conn.params

    case Accounts.get_user_by_from_id(from_id) do
      user when not is_nil(user) ->
        assign(conn, :current_user, user.from_id)

      nil ->
        token =
          ExTwitter.request_token(
            URI.encode_www_form(
              TweetBotWeb.Router.Helpers.auth_url(conn, :callback) <> "?from_id=#{from_id}"
            )
          )

        {:ok, authenticate_url} = ExTwitter.authenticate_url(token.oauth_token)

        conn
        |> json(%{
          "method" => "sendMessage",
          "chat_id" => from_id,
          "text" =>
            "请点击链接登录您的 Twitter 账号进行授权：<a href='" <> authenticate_url <> "'>登录 Twitter</a>",
          "parse_mode" => "HTML"
        })
        |> halt()
    end
  end

  defp configure_extwitter(conn, _) do
    # 读取用户 token
    user = Accounts.get_user_by_from_id!(conn.assigns.current_user)

    ExTwitter.configure(
      :process,
      Enum.concat(
        ExTwitter.Config.get_tuples(),
        access_token: user.access_token,
        access_token_secret: user.access_token_secret
      )
    )

    conn
  end

  def index(conn, %{"message" => %{"text" => "/start"}}) do
    json(conn, %{
      "method" => "sendMessage",
      "text" => "已授权，请直接发送消息",
      "chat_id" => conn.assigns.current_user
    })
  end

  def index(conn, %{"message" => %{"text" => "/z"}}) do
    [latest_tweet | _] = ExTwitter.user_timeline(count: 1)
    ExTwitter.destroy_status(latest_tweet.id)

    json(conn, %{
      "method" => "sendMessage",
      "text" => "撤销成功",
      "chat_id" => conn.assigns.current_user
    })
  end

  def index(conn, %{"message" => %{"photo" => photo} = message}) do
    caption = Map.get(message, "caption", "")

    case getFile(photo |> Enum.at(-1) |> Map.get("file_id")) do
      {:ok, file} ->
        try do
          %HTTPoison.Response{body: body} =
            HTTPoison.get!(
              "https://api.telegram.org/file/bot#{Application.get_env(:telegram_bot, :token)}/#{
                file |> Map.get("file_path")
              }",
              []
            )

          ExTwitter.update_with_media(caption, body)
          json(conn, %{})
        rescue
          e in ExTwitter.Error ->
            {:error, {:extwitter, e.message}}

          e in HTTPoison.Error ->
            {:error, {:httpoison, e.reason}}
        end
    end
  end

  # 处理 file 形式的图片
  def index(conn, %{
        "message" => %{"document" => %{"mime_type" => mime_type} = document} = message
      })
      when mime_type in ["image/png", "image/jpeg", "image/gif"] do
    caption = Map.get(message, "caption", "")

    case getFile(Map.get(document, "file_id")) do
      {:ok, file} ->
        try do
          %HTTPoison.Response{body: body} =
            HTTPoison.get!(
              "https://api.telegram.org/file/bot#{Application.get_env(:telegram_bot, :token)}/#{
                file |> Map.get("file_path")
              }",
              []
            )

          ExTwitter.update_with_media(caption, body)
          json(conn, %{})
        rescue
          e in ExTwitter.Error ->
            {:error, {:extwitter, e.message}}

          e in HTTPoison.Error ->
            {:error, {:httpoison, e.reason}}
        end
    end
  end

  def index(conn, %{"message" => %{"text" => text}}) do
    try do
      ExTwitter.update(text)
      json(conn, %{})
    rescue
      e in ExTwitter.Error ->
        {:error, {:extwitter, e.message}}
    end
  end
end
