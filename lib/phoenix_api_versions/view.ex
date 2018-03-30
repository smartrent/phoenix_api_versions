defmodule PhoenixApiVersions.View do
  defmacro __using__(_) do
    quote do
      alias Plug.Conn
      alias PhoenixApiVersions

      @doc """
      Catch calls to `render/2`, dispatch to the otherwise matching clause of `render/2`,
      and then transform the output properly depending on the API version of the request.
      """
      def render(template, %{conn: %{private: %{api_versioning_process_output?: true}}} = assigns) do
        conn = Conn.put_private(assigns.conn, PhoenixApiVersions.private_process_output_key(), false)
        assigns = Map.put(assigns, :conn, conn)
        output = render(template, assigns)

        PhoenixApiVersions.transform_response(output, assigns)
      end
    end
  end
end
