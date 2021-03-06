defmodule RunrollerUnrollTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @opts Runroller.Router.init([])

  setup do
    Runroller.Cache.purge

    {:ok, []}
  end

  def unroll(uri) do
    query = URI.encode_query(%{"uri" => uri})
    conn = conn(:get, "/unroll?#{query}")
    |> Runroller.Router.call(@opts)

    {:ok, body} = Poison.decode(conn.resp_body)
    {conn.status, body}
  end

  def assert_unrolled({status, body}, uri \\ "http://www.example.com/200") do
    assert status == 200
    assert body["unrolled_uri"] == uri
  end

  test "a URI with no redirects" do
    assert_unrolled unroll("http://www.example.com/200")
  end

  test "a URI with one redirect" do
    assert_unrolled unroll("http://www.example.com/one_to_200")
  end

  test "a URI with two redirects" do
    assert_unrolled unroll("http://www.example.com/two_to_200")
  end

  test "a URI with two redirects (cached)" do
    unroll("http://www.example.com/two_to_200")
    assert_unrolled unroll("http://www.example.com/two_to_200")
  end

  test "a URI with three redirects" do
    assert_unrolled unroll("http://www.example.com/three_to_200")
  end

  test "a URI with three redirects (cached)" do
    unroll("http://www.example.com/three_to_200")
    assert_unrolled unroll("http://www.example.com/three_to_200")
  end

  test "a URI with one 301 redirect" do
    assert_unrolled unroll("http://www.example.com/one_301_to_200")
  end

  test "a URI with a relative Location: header" do
    assert_unrolled unroll("http://www.example.com/302_to_relative")
  end

  test "a URI that times out" do
    {status, body} = unroll("http://www.example.com/timeout")
    assert status == 504
    assert body["error_code"] == "timeout"
  end

  test "a URI that returns 405 Method Not Allowed on a HEAD request" do
    assert_unrolled unroll("http://www.example.com/405_mna"),
      "http://www.example.com/405_mna"
  end

  test "a URI that returns 405 Method Not Allowed on a HEAD request retries as a GET, and redirects if a redirect is encountered." do
    assert_unrolled unroll("http://www.example.com/405_mna_to_200")
  end
end
