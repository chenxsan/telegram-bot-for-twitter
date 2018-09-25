defmodule Twitter do
  @callback request_token(String.t()) :: map()
  @callback authenticate_url(String.t()) :: {:ok, String.t()} | {:error, String.t()}
end
