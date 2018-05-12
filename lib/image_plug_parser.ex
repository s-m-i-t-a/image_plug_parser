defmodule ImagePlugParser do
  @moduledoc """
  Parses image in request body.
  """

  alias Plug.{Conn, Upload}

  @behaviour Plug.Parsers

  # @subtypes ["jpeg", "png"]

  def init(opts) do
    {subtypes, opts} = Keyword.pop(opts, :subtypes)
    {body_reader, opts} = Keyword.pop(opts, :body_reader, {Conn, :read_body, []})

    {body_reader, subtypes, opts}
  end

  def parse(%Conn{method: "PUT"} = conn, "image", subtype, _headers, {{mod, fun, args}, decoder, opts}) when subtype in @subtypes do
    conn
    |> Conn.read_body(opts)
    |> save()
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end

  defp save({:ok, data, conn}) do
    path = Upload.random_file!("fileupload")
    [ctype | _] = Conn.get_req_header(conn, "content-type")
    filename = get_filename(conn)

    File.write!(path, data)

    uploaded_file = %Plug.Upload{
      content_type: ctype,
      path: path,
      filename: filename,
    }

    {:ok, %{"file" => uploaded_file}, conn}
  end

  defp save({:more, _data, conn}) do
    {:error, :too_large, conn}
  end

  defp save({:error, :timeout}) do
    raise Plug.TimeoutError
  end

  defp save({:error, _}) do
    raise Plug.BadRequestError
  end

  defp get_filename(%Plug.Conn{path_info: ["api", "files", page_id, filename]}) do
    "#{page_id}/#{filename}"
  end
end
