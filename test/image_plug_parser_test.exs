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

  setup do
    {:ok, opts: ImagePlugParser.init(@opts)}
  end

  test "save uploaded image to tmp", %{opts: opts} do
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
end
