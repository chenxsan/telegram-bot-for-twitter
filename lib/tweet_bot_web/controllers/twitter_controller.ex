defmodule TweetBotWeb.TwitterController do
  use TweetBotWeb, :controller

  import TelegramBot
  alias TweetBot.Accounts
  plug(:find_user)
  plug(:configure_extwitter)

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

        sendMessage(
          from_id,
          "请点击链接登录您的 Twitter 账号进行授权：<a href='" <> authenticate_url <> "'>登录 Twitter</a>",
          parse_mode: "HTML"
        )

        conn |> halt()
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
    sendMessage(conn.assigns.current_user, "已授权，请直接发送消息")
    json(conn, %{})
  end

  def index(conn, %{"message" => %{"text" => "/z"}}) do
    [latest_tweet | _] = ExTwitter.user_timeline(count: 1)
    ExTwitter.destroy_status(latest_tweet.id)
    sendMessage(conn.assigns.current_user, "撤销成功")
    json(conn, %{})
  end

  def index(conn, %{"message" => %{"text" => text}}) do
    try do
      ExTwitter.update(text)
    rescue
      e in ExTwitter.Error -> sendMessage(conn.assigns.current_user, "#{e.message}")
    end

    json(conn, %{})
  end
end
