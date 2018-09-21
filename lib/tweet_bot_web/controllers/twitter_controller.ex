defmodule TweetBotWeb.TwitterController do
  use TweetBotWeb, :controller

  import TelegramBot

  def index(conn, %{"message" => %{"from" => %{"id" => from_id}, "text" => text}}) do
    sendMessage(from_id, "你好")
    json(conn, %{})
  end
end
