defmodule TweetBotWeb.TwitterControllerTest do
  use TweetBotWeb.ConnCase
  import Mox

  setup :verify_on_exit!

  @valid_message %{
    "message" => %{
      "from" => %{
        "id" => 123
      },
      "text" => "/start"
    }
  }

  test "POST /api/twitter with /start first time", %{conn: conn} do
    TwitterMock
    |> expect(:request_token, fn _ -> %{oauth_token: ""} end)
    |> expect(:authenticate_url, fn _ -> {:ok, "https://blog.zfanw.com"} end)

    conn = post(conn, "/api/twitter", @valid_message)

    assert json_response(conn, 200) == %{
             "chat_id" => 123,
             "method" => "sendMessage",
             "parse_mode" => "HTML",
             "text" => "请点击链接登录您的 Twitter 账号进行授权：<a href='https://blog.zfanw.com'>登录 Twitter</a>"
           }
  end
end
