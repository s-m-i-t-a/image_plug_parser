defmodule ImagePlugParser do
  @moduledoc """
  Parses image in request body.
  """

  alias Plug.{Conn, Upload}

  @behaviour Plug.Parsers

  def init(opts) do
    {subtypes, opts} = Keyword.pop(opts, :subtypes)
    {body_reader, opts} = Keyword.pop(opts, :body_reader, {Conn, :read_body, []})

    unless subtypes do
      raise ArgumentError, "Image parser expects a :subtypes option"
    end

    {body_reader, subtypes, opts}
  end

  def parse(%Conn{method: "PUT"} = conn, "image", subtype, _headers, {body_reader, subtypes, opts}) do
    if subtype in subtypes do
      conn
      |> read(body_reader, opts)
      |> save()
    else
      {:next, conn}
    end
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end

  defp read(conn, {mod, fun, args}, opts) do
    apply(mod, fun, [conn, opts | args])
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

  defp get_filename(%Plug.Conn{params: params}) do
    params
    |> Map.get("filename")
    |> Path.join()
  end
end
