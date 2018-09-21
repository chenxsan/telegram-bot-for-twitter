defmodule TweetBotWeb.AuthController do
  use TweetBotWeb, :controller

  def callback(conn, %{"oauth_token" => oauth_token, "oauth_verifier" => oauth_verifier}) do
    # 获取 access token
    {:ok, token} = ExTwitter.access_token(oauth_verifier, oauth_token)
    IO.inspect(token)
    text(conn, "授权成功，请关闭此页面")
  end
end
