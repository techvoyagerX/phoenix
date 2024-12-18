defmodule Phoenix.Integration.HTTPClient do
  @moduledoc """
  Provides utility functions for making HTTP requests during integration tests.
  """

  @type method :: :get | :post | :put | :delete | :patch | :head | :options
  @type url :: String.t()
  @type headers :: map()
  @type body :: binary() | map()

  @doc """
  Performs an HTTP request and returns a response.

  ## Parameters
    - `method` (atom): The HTTP method, e.g., `:get`, `:post`.
    - `url` (string): The URL to request, e.g., `"http://example.com"`.
    - `headers` (map): A map of headers.
    - `body` (optional): The request body, which can be a string or a map.

  ## Examples

      iex> HTTPClient.request(:get, "http://127.0.0.1", %{})
      {:ok, %{status: 200, headers: [...], body: "..."}}

      iex> HTTPClient.request(:post, "http://127.0.0.1", %{}, %{param1: "val1"})
      {:ok, %{status: 201, headers: [...], body: "..."}}

      iex> HTTPClient.request(:get, "http://unknownhost", %{})
      {:error, :nxdomain}

  """
  @spec request(method, url, headers, body) :: {:ok, map()} | {:error, term()}
  def request(method, url, headers, body \\ "")

  def request(method, url, headers, body) when is_map(body) do
    headers = Map.put_new(headers, "content-type", "application/x-www-form-urlencoded")
    request(method, url, headers, URI.encode_query(body))
  end

  def request(method, url, headers, body) when is_binary(body) do
    headers = normalize_headers(headers)
    url = String.to_charlist(url)

    profile = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower) |> String.to_atom
    {:ok, pid} = :inets.start(:httpc, profile: profile)

    request_opts = [body_format: :binary]

    response =
      case method do
        :get -> :httpc.request(:get, {url, headers}, [], request_opts, pid)
        _ ->
          content_type = Map.get(headers, "content-type", "text/plain") |> String.to_charlist()
          :httpc.request(method, {url, headers, content_type, body}, [], request_opts, pid)
      end

    :inets.stop(:httpc, pid)
    format_response(response)
  end

  defp normalize_headers(headers) do
    headers
    |> Enum.map(fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)
  end

  defp format_response({:ok, {{_http_version, status, _reason_phrase}, headers, body}}) do
    {:ok, %{status: status, headers: parse_headers(headers), body: body}}
  end

  defp format_response({:error, reason}), do: {:error, reason}

  defp parse_headers(headers) do
    headers
    |> Enum.map(fn {k, v} -> {String.downcase(to_string(k)), v} end)
    |> Enum.into(%{})
  end
end
