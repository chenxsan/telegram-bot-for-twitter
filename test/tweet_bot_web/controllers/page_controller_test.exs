defmodule TweetBotWeb.PageControllerTest do
  use TweetBotWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert html_response(conn, 200) =~ "Hello Tweet for me bot!"
  end
end
