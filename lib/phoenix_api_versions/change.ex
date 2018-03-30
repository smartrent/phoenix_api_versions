defmodule PhoenixApiVersions.Change do
  @moduledoc """
  A behaviour for a module that represents a distinct "change" made in an API version.

  Also contains a `use` macro with default implementations of the behaviour.

  ## Using the Macro

  The best way to use this behavior is to `use` it, which provides default
  implementations for `transform_request` and `transform_response`.

      defmodule MyApiChange do
        use PhoenixApiVersions.Change

        def routes do
          # ...
        end
      end

  Since the macro provides default implementations, you can choose to modify
  only the output or only the input.

  ## Routes

  The `routes` callback takes a list of `{controller_module, action}` tuples.

  The change will *only* be applied whenever the current request routes to one of
  the controller and action pairs given. In this way, a single change module can
  affect multiple routes. (Useful if a logical change needs to happen in multiple places.)

  ## Macro Helper Callbacks

  When using the macro (`use PhoenixApiVersions.Change`), overrideable helper
  functions are available that only expose the input or output JSON:

      defmodule MyApiChange do
        use PhoenixApiVersions.Change

        def transform_request_params(params) do
          # params is incoming conn.params
        end

        # first argument is whatever the view output
        # second argument is the controller module
        # third argument is the controller action
        def transform_response(output, MyFooController, :index) do
          # return modified output
        end
        def transform_response(output, MyBarController, :show) do
          # return modified output
        end
      end
  """

  alias Plug.Conn

  @callback routes() :: [{module(), atom()}]
  @callback transform_request(Conn.t()) :: Conn.t()
  @callback transform_response(any(), map()) :: any()

  defmacro __using__(_) do
    quote do
      @behaviour PhoenixApiVersions.Change

      def transform_request(conn) do
        %{phoenix_controller: c, phoenix_action: a} = conn.private

        conn =
          conn
          |> Map.put(:body_params, transform_request_body_params(conn.body_params, c, a))
          |> Map.put(:query_params, transform_request_body_params(conn.query_params, c, a))
          |> Map.put(:path_params, transform_request_path_params(conn.path_params, c, a))

        params =
          conn.params
          |> Map.merge(conn.body_params)
          |> Map.merge(conn.query_params)
          |> Map.merge(conn.path_params)

        conn
        |> Map.put(:params, params)
      end

      def transform_request_body_params(body_params, _controller_module, _action) do
        body_params
      end

      def transform_request_query_params(query_params, _controller_module, _action) do
        query_params
      end

      def transform_request_path_params(path_params, _controller_module, _action) do
        path_params
      end

      def transform_response(output, assigns) do
        %{phoenix_controller: c, phoenix_action: a} = assigns.conn.private
        transform_response(output, c, a)
      end

      def transform_response(output, _controller_module, _action) do
        output
      end

      defoverridable transform_request: 1,
                     transform_request_body_params: 3,
                     transform_request_query_params: 3,
                     transform_request_path_params: 3,
                     transform_response: 2,
                     transform_response: 3
    end
  end
end
