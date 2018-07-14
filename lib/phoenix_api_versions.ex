defmodule PhoenixApiVersions do
  @moduledoc File.read!("README.md")

  alias Plug.Conn
  alias Phoenix.Controller
  alias PhoenixApiVersions.Version

  def private_changes_key, do: :phoenix_api_versions_changes
  def private_process_output_key, do: :phoenix_api_versions_process_output?

  @doc """
  Generates the list of valid versions and the changes defined by each version.

  ## Example

      alias PhoenixApiVersions.Version

      def versions do
        [
          %Version{
            name: "v1",
            changes: [
              V1.AccountTypes,
              V1.CollapseEventRequest,
              V1.EventAccountToUserID
            ]
          },
          %Version{
            name: "v2",
            changes: [
              V1.LegacyTransfers
            ]
          },
          %Version{
            name: "v3",
            changes: [
              V1.AutoexpandChargeDispute,
              V1.AutoexpandChargeRule
            ]
          }
        ]
      end

  """
  @callback versions() :: [Version.t()]

  @doc """
  Processes the `Conn` whenever the consumer makes a request that cannot be mapped to a version.

  (Example: The app defines `v1` and `v2` but the consumer visits API version `v3` or `hippopotamus`.)

  This callback does not need to call `Conn.halt()`; the library does so immediately after this callback returns.

  ## Example

      def version_not_found(conn) do
        conn
        |> Conn.put_status(:not_found)
        |> Controller.render("404.json", %{})
      end

  Note that in this example, a `render/1` function matching `"404.json"` must exist in the View.
  (Presumably through a project-wide macro such as the `Web` module's `view` macro. This is a great hooking
  point for application-level abstractions.)

  The PhoenixApiVersions library intentionally refrains from assuming anything about the application,
  and leaves this work up to library consumers.
  """
  @callback version_not_found(Conn.t()) :: Conn.t()

  @doc """
  Generates the version name from the `Conn`.

  Applications may choose to allow API consumers to specify the API version in a number of ways:

  1. Via a URL segment, such as `/api/v3/profile`
  2. Via a request header, such as `X-Api-Version: v3`
  3. Via the `Accept` header, such as `Accept: application/vnd.github.v3.json`

  Rather than enforcing a specific method, PhoenixApiVersions provides this callback so that
  any method can be used.

  If the callback is unable to discover a version, applications can choose to do one of the following:

  1. Provide a default fallback version
  2. Return `nil` or any other value that isn't the `name` of a `Version`.

  ## Examples

      # Get the version from a URL segment.
      # Assumes all API urls have `/:api_version/` in them.
      def version_name(%{path_params: %{"api_version" => v}}), do: v

      # Get the version from `X-Api-Version` header.
      # Return the latest version as a fallback if none is provided.
      def version_name(conn) do
        conn
        |> Plug.Conn.get_req_header("x-api-version")
        |> List.first()
        |> case do
          nil -> "v3"
          v -> v
        end
      end

      # Get the version from `Accept` header.
      # Return `nil` if none is provided so that the "not found" response is displayed.
      #
      # Assumes a format like this:
      #   "application/vnd.github.v3.json"
      def version_name(conn) do
        accept_header =
          conn
          |> Plug.Conn.get_req_header("accept")
          |> List.first()

        ~r/application\/vnd\.github\.(?<version>.+)\.json/
        |> Regex.named_captures(accept_header)
        |> case do
          %{"version" => v} -> v
          nil -> nil
        end
      end
  """
  @callback version_name(Conn.t()) :: any()

  @doc """
  Return whether or not any changes should be applied at all
  for the given request.

  This should be used as an escape hatch for routes that shouldn't
  be governed by PhoenixApiVersions.

  For example, most route definitions might begin with `/api/:api_version`,
  and there might be hard-coded route definitions above overriding a
  single version, so that they start with `/api/v1`. In this case,
  `apply_changes_for_request?` might be configured to return `false`
  if `api_version` is missing from `params`.
  """
  @callback apply_changes_for_request?(Conn.t()) :: boolean()

  defmacro __using__(_) do
    quote do
      @behaviour PhoenixApiVersions

      def apply_changes_for_request?(%Conn{}), do: true

      defoverridable apply_changes_for_request?: 1
    end
  end

  def configuration_module do
    Application.get_env(:phoenix_api_versions, :versions)
  end

  def handle_invalid_version(%Conn{} = conn),
    do: apply(configuration_module(), :version_not_found, [conn])

  def transform_request(%Conn{} = conn) do
    conn.private[private_changes_key()]
    |> Enum.reduce(conn, fn change_module, conn ->
      apply(change_module, :transform_request, [conn])
    end)
  end

  def transform_response(output, assigns) do
    assigns.conn.private[private_changes_key()]
    |> Enum.reverse()
    |> Enum.reduce(output, fn change_module, output ->
      apply(change_module, :transform_response, [output, assigns])
    end)
  end

  @doc """
  Given a conn and a list of Version structs:

  1. Traverse the list of Versions until one is found with a name that matches the current API version name (and discard the initial ones that didn't match)
  2. Traverse the Change modules of the remaining Versions, filtering out Change modules that don't match the current route
  3. Return all remaining Change modules (those that match the current route)

  Note that the order of both the Versions and Changes matter.
  All Versions listed before the match will be discarded.
  The resulting changes will be applied in the order listed.
  """
  @spec changes_to_apply(Conn.t()) :: [module()] | {:error, :no_matching_version_found}
  def changes_to_apply(%Conn{} = conn) do
    version_name = apply(configuration_module(), :version_name, [conn])
    versions = apply(configuration_module(), :versions, [])

    changes_to_apply(conn, version_name, versions)
  end

  @spec changes_to_apply(Conn.t(), any(), [Version.t()]) ::
          [module()] | {:error, :no_matching_version_found}
  defp changes_to_apply(conn, version_name, [%Version{name: version_name} | _] = versions) do
    versions
    |> Enum.flat_map(fn
      %Version{changes: changes} ->
        changes

      _ ->
        raise_invalid_version_type()
    end)
    |> Enum.filter(fn change_module ->
      change_module
      |> apply(:routes, [])
      |> Enum.any?(fn {controller, action} ->
        controller == Controller.controller_module(conn) && action == Controller.action_name(conn)
      end)
    end)
  end

  defp changes_to_apply(conn, version_name, [version | rest]) when is_map(version) do
    if Map.get(version, :__struct__) == Version do
      changes_to_apply(conn, version_name, rest)
    else
      raise_invalid_version_type()
    end
  end

  defp changes_to_apply(_conn, _version_name, []), do: {:error, :no_matching_version_found}

  @doc """
  Return whether or not any changes should be applied at all for the given request.

  (Used as an escape hatch for routes that shouldn't be governed by PhoenixApiVersions.)
  """
  @spec apply_changes_for_request?(Conn.t()) :: boolean()
  def apply_changes_for_request?(conn) do
    apply(configuration_module(), :apply_changes_for_request?, [conn])
  end

  defp raise_invalid_version_type do
    raise "Each version returned by versions/1 must be a PhoenixApiVersions.Version struct"
  end
end
