defmodule TweetBotWeb.AuthController do
  use TweetBotWeb, :controller
  alias TweetBot.Accounts

  def callback(conn, %{
        "from_id" => from_id,
        "oauth_token" => oauth_token,
        "oauth_verifier" => oauth_verifier
      }) do
    # 获取 access token
    case ExTwitter.access_token(oauth_verifier, oauth_token) do
      {:ok, token} ->
        case Accounts.get_user_by_from_id(from_id) do
          user when not is_nil(user) ->
            case Accounts.update_user(user, %{
                   access_token: token.oauth_token,
                   access_token_secret: token.oauth_token_secret
                 }) do
              {:ok, _user} -> text(conn, "授权成功，请关闭此页面")
              {:error, _changeset} -> text(conn, "授权失败。")
            end

          nil ->
            case Accounts.create_user(%{
                   from_id: from_id,
                   access_token: token.oauth_token,
                   access_token_secret: token.oauth_token_secret
                 }) do
              {:ok, _} -> text(conn, "授权成功，请关闭此页面")
              {:error, _changeset} -> text(conn, "授权失败。")
            end
        end

      {:error, reason} ->
        text(conn, "授权失败：#{reason}")
    end
  end
end
