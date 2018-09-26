defmodule TweetBotWeb.TwitterController do
  use TweetBotWeb, :controller

  import TelegramBot
  alias TweetBot.Accounts
  plug(:find_user)
  plug(:configure_extwitter)
  action_fallback(FallbackController)

  @twitter_api Application.get_env(:tweet_bot, :twitter_api)

  defp find_user(conn, _) do
    %{"message" => %{"from" => %{"id" => from_id}}} = conn.params

    case Accounts.get_user_by_from_id(from_id) do
      user when not is_nil(user) ->
        assign(conn, :current_user, user.from_id)

      nil ->
        get_twitter_oauth(conn, from_id) |> halt()
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
    try do
      ExTwitter.verify_credentials()

      json(conn, %{
        "method" => "sendMessage",
        "text" => "已授权，请直接发送消息",
        "chat_id" => conn.assigns.current_user
      })
    rescue
      _ ->
        %{"message" => %{"from" => %{"id" => from_id}}} = conn.params

        get_twitter_oauth(conn, from_id) |> halt()
    end
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
        tweet_photo(conn, file, caption)
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
        tweet_photo(conn, file, caption)
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

  defp get_twitter_oauth(conn, from_id) do
    token =
      @twitter_api.request_token(
        URI.encode_www_form(
          TweetBotWeb.Router.Helpers.auth_url(conn, :callback) <> "?from_id=#{from_id}"
        )
      )

    {:ok, authenticate_url} = @twitter_api.authenticate_url(token.oauth_token)

    conn
    |> json(%{
      "method" => "sendMessage",
      "chat_id" => from_id,
      "text" =>
        gettext("Click link to sign in Twitter and authorize: ") <>
          "<a href='" <> authenticate_url <> "'>" <> gettext("Sign in with Twitter") <> "</a>",
      "parse_mode" => "HTML"
    })
  end

  defp tweet_photo(conn, file, caption) do
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
