defmodule PhoenixApiVersions do
  @moduledoc """
  Documentation for PhoenixApiVersions.
  """

  @doc """
  Hello world.

  ## Examples

      iex> PhoenixApiVersions.hello
      :world

  """

  alias Plug.Conn
  alias Phoenix.Controller
  alias PhoenixApiVersions.Version

  def private_changes_key, do: :phoenix_api_versions_changes
  def private_process_output_key, do: :api_versioning_process_output?

  @callback versions() :: [Version.t()]
  @callback route_not_found(Conn.t()) :: Conn.t()
  @callback version_name(Conn.t()) :: any()

  defmacro __using__(_) do
    quote do
      @behaviour PhoenixApiVersions
    end
  end

  def configuration_module do
    Application.get_env(:phoenix_api_versions, :versions)
  end

  def handle_invalid_version(%Conn{} = conn),
    do: apply(configuration_module(), :route_not_found, [conn])

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
    |> Enum.flat_map(fn %Version{changes: changes} ->
      changes
    end)
    |> Enum.filter(fn change_module ->
      change_module
      |> apply(:routes, [])
      |> Enum.any?(fn {controller, action} ->
        controller == Controller.controller_module(conn) && action == Controller.action_name(conn)
      end)
    end)
  end

  defp changes_to_apply(conn, version_name, [_ | rest]),
    do: changes_to_apply(conn, version_name, rest)

  defp changes_to_apply(_conn, _version_name, []), do: {:error, :no_matching_version_found}
end
