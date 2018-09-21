defmodule TweetBotWeb.AuthController do
  use TweetBotWeb, :controller

  def callback(conn, %{"oauth_token" => oauth_token, "oauth_verifier" => oauth_verifier}) do
    # 获取 access token
    {:ok, token} = ExTwitter.access_token(oauth_verifier, oauth_token)

    ExTwitter.configure(
      :process,
      Enum.concat(
        ExTwitter.Config.get_tuples(),
        access_token: token.oauth_token,
        access_token_secret: token.oauth_token_secret
      )
    )

    ExTwitter.update("I just sign up telegram bot tweet_for_me_bot.")
    text(conn, "授权成功，请关闭此页面")
  end
end
