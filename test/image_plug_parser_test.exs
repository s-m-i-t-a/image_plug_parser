defmodule ImagePlugParserTest do
  use ExUnit.Case
  use Plug.Test

  @opts [
    length: 8_000_000,
    read_length: 1_000_000,
    read_timeout: 15_000,
    subtypes: ["jpeg", "png"]
  ]

  @image_path Path.expand("fixtures/test.jpg", __DIR__)

  defmodule TestRouter do
    use Plug.Router

    plug :match
    plug :dispatch

    put "/*filename" do
      send_resp(conn, 200, "OK")
    end
  end

  defmodule BodyReader do
    def too_large(conn, _opts) do
      {:more, nil, conn}
    end

    def timeout(_conn, _opts) do
      {:error, :timeout}
    end

    def bad_request(_conn, _opts) do
      {:error, :bad_request}
    end
  end

  test "save uploaded image to tmp" do
    opts = ImagePlugParser.init(@opts)
    filename = "56790c04fdec4657b378fed3/pokus.jpg"
    file_content = File.read!(@image_path)

    result =
      conn(:put, "/" <> filename, file_content)
      |> put_req_header("content-type", "image/jpeg")
      |> TestRouter.call(TestRouter.init([]))
      |> ImagePlugParser.parse("image", "jpeg", %{}, opts)

    {:ok, %{"file" => %Plug.Upload{content_type: "image/jpeg", filename: ^filename, path: file}}, _conn} = result

    assert File.read!(file) == file_content
  end

  test "should raise argument error if subtypes isn't set" do
    assert_raise(ArgumentError, fn -> ImagePlugParser.init([]) end)
  end

  test "should return too large error" do
    opts =
      @opts
      |> Keyword.put(:body_reader, {BodyReader, :too_large, []})
      |> ImagePlugParser.init()

    filename = "56790c04fdec4657b378fed3/pokus.jpg"
    file_content = File.read!(@image_path)

    {:error, msg, _} =
      conn(:put, "/" <> filename, file_content)
      |> put_req_header("content-type", "image/jpeg")
      |> TestRouter.call(TestRouter.init([]))
      |> ImagePlugParser.parse("image", "jpeg", %{}, opts)

    assert msg == :too_large
  end

  test "should raise timeout error" do
    opts =
      @opts
      |> Keyword.put(:body_reader, {BodyReader, :timeout, []})
      |> ImagePlugParser.init()

    filename = "56790c04fdec4657b378fed3/pokus.jpg"
    file_content = File.read!(@image_path)

    assert_raise(Plug.TimeoutError, fn ->
      conn(:put, "/" <> filename, file_content)
      |> put_req_header("content-type", "image/jpeg")
      |> TestRouter.call(TestRouter.init([]))
      |> ImagePlugParser.parse("image", "jpeg", %{}, opts)
    end)
  end

  test "should raise bad request error" do
    opts =
      @opts
      |> Keyword.put(:body_reader, {BodyReader, :bad_request, []})
      |> ImagePlugParser.init()

    filename = "56790c04fdec4657b378fed3/pokus.jpg"
    file_content = File.read!(@image_path)

    assert_raise(Plug.BadRequestError, fn ->
      conn(:put, "/" <> filename, file_content)
      |> put_req_header("content-type", "image/jpeg")
      |> TestRouter.call(TestRouter.init([]))
      |> ImagePlugParser.parse("image", "jpeg", %{}, opts)
    end)
  end
end
