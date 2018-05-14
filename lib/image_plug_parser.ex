defmodule ImagePlugParser do
  @moduledoc """
  Parses image in PUT request body.

  ## Usage

  Image parser must be used only in controller

      defmodule Server.Web.FilesController do
        use Server.Web, :controller

        plug Plug.Parsers,
          parsers: [ImagePlugParser],
          subtypes: ["jpeg", "png"]

        def upload(conn, %{"file" => %{filename: filename, path: path, content_type: mimetype}}) do
          path
          |> FilesManager.upload(filename, mimetype)
          |> response(conn)
        end
      end

  and router must set wildcard path with name `filename`

      defmodule Server.Web.Router do
        use Server.Web, :router

        pipeline :api do
          plug :accepts, ["json"]
        end

        scope "/api", Server.Web do
          pipe_through :api

          put "/files/:page_id/*filename", FilesController, :upload
        end
      end

  ## Options

    * `:subtypes` - list of supported image content types, eg. jpeg or png

  All options supported by `Plug.Conn.read_body/2` are also supported here.
  They are repeated here for convenience:

    * `:length` - sets the maximum number of bytes to read from the request,
      defaults to 8_000_000 bytes
    * `:read_length` - sets the amount of bytes to read at one time from the
      underlying socket to fill the chunk, defaults to 1_000_000 bytes
    * `:read_timeout` - sets the timeout for each socket read, defaults to
      15_000ms

  So by default, `Plug.Parsers` will read 1_000_000 bytes at a time from the
  socket with an overall limit of 8_000_000 bytes.
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
