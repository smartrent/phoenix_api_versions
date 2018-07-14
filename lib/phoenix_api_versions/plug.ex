defmodule PhoenixApiVersions.Plug do
  @moduledoc """
  A plug to be used in the `controller` macro in a Phoenix application's `Web` module. (The file containing this module is typically called `web.ex`)

  Required for installation of the `PhoenixApiVersions` library.

  ## Example

      # In web.ex

      def controller do
        quote do
          # ...

          plug PhoenixApiVersions.Plug # <----- Add this

          # ...
        end
      end

  """

  alias Plug.Conn
  alias PhoenixApiVersions

  def init(_), do: nil

  @doc """
  Finds the API Version and saves the changes that need applied into the conn.

  If an API Version isn't found, routes to the "version not found" handler.
  """
  def call(conn, _) do
    if PhoenixApiVersions.apply_changes_for_request?(conn) do
      conn
      |> PhoenixApiVersions.changes_to_apply()
      |> case do
        {:error, :no_matching_version_found} ->
          conn
          |> PhoenixApiVersions.handle_invalid_version()
          |> Conn.halt()

        changes_to_apply when is_list(changes_to_apply) ->
          conn
          |> Conn.put_private(PhoenixApiVersions.private_changes_key(), changes_to_apply)
          |> Conn.put_private(PhoenixApiVersions.private_process_output_key(), true)
          |> PhoenixApiVersions.transform_request()
      end
    else
      conn
      |> Conn.put_private(PhoenixApiVersions.private_process_output_key(), false)
    end
  end
end
