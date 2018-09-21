defmodule TweetBotWeb.TwitterController do
  use TweetBotWeb, :controller

  import TelegramBot
  alias TweetBot.Accounts
  plug(:find_user)

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
          "请点击链接登录您的 Twitter 账号授权：<a href='" <> authenticate_url <> "'>登录 Twitter</a>",
          parse_mode: "HTML"
        )

        conn |> halt()
    end
  end

  def index(conn, %{"message" => %{"from" => %{"id" => from_id}, "text" => text}}) do
    case text do
      "/start" ->
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

      _ ->
        sendMessage(from_id, "你好")
    end

    json(conn, %{})
  end
end
