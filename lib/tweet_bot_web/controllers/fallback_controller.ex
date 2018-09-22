defmodule FallbackController do
  use Phoenix.Controller

  def call(conn, {:error, {_, reason}}) do
    json(conn, %{
      "method" => "sendMessage",
      "chat_id" => conn.assigns.current_user,
      "text" => reason
    })
  end
end
