defmodule TweetBotWeb.AuthController do
  use TweetBotWeb, :controller
  alias TweetBot.Accounts

  def callback(conn, %{
        "from_id" => from_id,
        "oauth_token" => oauth_token,
        "oauth_verifier" => oauth_verifier
      }) do
    # 获取 access token
    {:ok, token} = ExTwitter.access_token(oauth_verifier, oauth_token)

    case Accounts.create_user(%{
           from_id: from_id,
           access_token: token.oauth_token,
           access_token_secret: token.oauth_token_secret
         }) do
      {:ok, _} -> text(conn, "授权成功，请关闭此页面")
      {:error, reason} -> text(conn, "授权失败：#{reason}")
    end
  end
end
