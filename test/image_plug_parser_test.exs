defmodule ImagePlugParserTest do
  use ExUnit.Case
  use Plug.Test

  @opts [
    length: 8_000_000,
    read_length: 1_000_000,
    read_timeout: 15_000,
  ]

  @image_path Path.expand("fixtures/test.jpg", __DIR__)

  test "save uploaded image to tmp" do
    filename = "56790c04fdec4657b378fed3/pokus.jpg"
    file_content = File.read!(@image_path)

    result =
      conn(:put, "/api/files/" <> filename, file_content)
      |> put_req_header("content-type", "image/jpeg")
      |> ImagePlugParser.parse("image", "jpeg", %{}, @opts)

    {:ok, %{"file" => %Plug.Upload{content_type: "image/jpeg", filename: ^filename, path: file}}, _conn} = result

    assert File.read!(file) == file_content
  end
end
