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

  ## Helper Callbacks

  When using the macro (`use PhoenixApiVersions.Change`), overrideable helper
  functions are available that only expose the input or output JSON instead of the entire Conn:

  ### `transform_request_body_params(body_params, controller_module, action) :: transformed_body_params`

  `conn.body_params` is passed to this function before sending to the controller. Return the transformed `body_params`.

  ### `transform_request_query_params(query_params, controller_module, action) :: transformed_query_params`

  `conn.query_params` is passed to this function before sending to the controller. Return the transformed `query_params`.

  ### `transform_request_path_params(path_params, controller_module, action) :: transformed_path_params`

  `conn.path_params` is passed to this function before sending to the controller. Return the transformed `path_params`.

  ### `transform_response(view_output, controller_module, action) :: transformed_view_output`

  The data returned by the view function (presumably a map) is passed to this function. Return the data with transformations applied.

  ### Example

      defmodule MyApiChange do
        use PhoenixApiVersions.Change

        def routes do
          [
            {FooController, :create},
            {FooController, :update},
            {FooController, :index},
            {BarController, :show}
          ]
        end

        def transform_request_body_params(params, FooController, :create) do
          transformed_params = # Perform transformations

          transformed_params
        end

        # first argument is whatever the view output
        # second argument is the controller module
        # third argument is the controller action
        def transform_response(output, FooController, :index) do
          # return modified output
        end
        def transform_response(output, BarController, :show) do
          # return modified output
        end
      end
  """

  alias Plug.Conn

  @doc """
  Generates a list of routes for which PhoenixApiVersions will transform the JSON
  input/output using this change.

  This is a "whitelist" of Controller/action pairs. For any route that doesn't
  lead to a Controller/action pair in this list, PhoenixApiVersions will not apply
  the change module.

  ## Example

      def routes do
        [
          {DeviceController, :show},
          {DeviceController, :create},
          {DeviceController, :update},
          {DeviceController, :index}
        ]
      end

  """
  @callback routes() :: [{module(), atom()}]

  @doc """
  Transforms the Conn before it is handled by the controller.

  The conn can be modified in any way. For a typical use case,
  Change modules should override the helper callbacks.
  (`transform_request_body_params/3`, `transform_request_query_params/3`, and `transformed_path_params/3`.)

  The helper callbacks are useful to avoid having to re-populate the `conn` with the new
  params; simply return the transformed value and the base implementation of
  `transform_request` will populate the `conn` appropriately.

  Furthermore, the helper callbacks are passed the `controller_module` and `action` as the second and third arguments.
  In this way, the module can decide how to transform the output based on the current route.

  ## Example

      def transform_request_body_params(%{"name" => _} = params, DeviceController, action)
          when action in [:create, :update] do
        params
        |> Map.put("description", params["name"])
        |> Map.drop(["name"])
      end

  """
  @callback transform_request(Conn.t()) :: Conn.t()

  @doc """
  Transforms view output before sending the response.

  Is passed `assigns` as the second argument, as such:

  ```elixir
  transform_response(view_output, assigns)
  ```

  The transformed view data is returned. The `Conn` cannot be modified by this function. However, it is available via `assigns.conn`.

  For a typical use case, Change modules should override the helper callback:
  `transform_response/3`

  This is passed the `view_output`, followed by the `controller_module` and `action`.
  In this way, the module can decide how to transform the output based on the current route.

  ## Example

      def transform_response(%{data: device} = output, DeviceController, action)
          when action in [:create, :update, :show] do
        output
        |> Map.put(:data, device_output_to_v1(device))
      end

  """
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
