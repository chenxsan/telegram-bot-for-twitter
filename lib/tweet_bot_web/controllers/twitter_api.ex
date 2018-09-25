defmodule TwitterAPI do
  @behaviour Twitter

  def request_token(redirect_url \\ nil) do
    ExTwitter.request_token(redirect_url)
  end

  def authenticate_url(token) do
    ExTwitter.authenticate_url(token)
  end
end
