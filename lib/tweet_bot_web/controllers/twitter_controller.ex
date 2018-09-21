defmodule TweetBotWeb.TwitterController do
  use TweetBotWeb, :controller

  def index(conn, %{"message" => %{"from" => %{"id" => from_id}, "text" => text}}) do
    json(conn, %{})
  end
end
