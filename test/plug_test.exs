defmodule PhoenixApiVersions.PlugTest do
  use ExUnit.Case, async: true

  alias Plug.Conn

  defmodule V1.ChangeA do
    use PhoenixApiVersions.Change

    def routes do
      [
        {MatchedController, :matched_action}
      ]
    end
  end

  defmodule V1.ChangeB do
    use PhoenixApiVersions.Change

    def routes do
      [
        {MatchedController, :matched_action},
        {MatchedController, :action_only_caught_by_v1_change_b}
      ]
    end
  end

  defmodule V2.Change do
    use PhoenixApiVersions.Change

    def routes do
      [
        {MatchedController, :matched_action}
      ]
    end
  end

  defmodule TestVersions do
    use PhoenixApiVersions

    alias PhoenixApiVersions.Version
    alias Plug.Conn

    def version_not_found(conn) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(:not_found, "{\"error\": \"not_found\"}")
    end

    def version_name(conn) do
      conn.path_params["api_version"]
    end

    def versions do
      [
        %Version{
          name: "version1",
          changes: [
            V1.ChangeA,
            V1.ChangeB
          ]
        },
        %Version{
          name: "version2",
          changes: [
            V2.Change
          ]
        },
        %Version{
          name: "version3",
          changes: []
        }
      ]
    end
  end

  def conn(version, controller \\ MatchedController, action \\ :matched_action) do
    params = %{"body" => "original_value"}

    %Conn{
      private: %{
        phoenix_controller: controller,
        phoenix_action: action
      },
      body_params: params,
      path_params: %{"api_version" => version},
      params: params
    }
  end

  describe "PhoenixApiVersions.Plug" do
    test "Assigns an ordered list of change modules into conn.private.phoenix_api_versions_changes" do
      transformed_conn = PhoenixApiVersions.Plug.call(conn("version1"), nil)

      assert [
        V1.ChangeA,
        V1.ChangeB,
        V2.Change
      ] = transformed_conn.private.phoenix_api_versions_changes
    end

    test "Only adds change modules to conn.private.phoenix_api_versions_changes if their routes/0 definition contains the current route" do
      conn = conn("version1", MatchedController, :action_only_caught_by_v1_change_b)
      transformed_conn = PhoenixApiVersions.Plug.call(conn, nil)

      assert [V1.ChangeB] = transformed_conn.private.phoenix_api_versions_changes
    end

    test "Applies Versions.version_not_found/1 to conn and halts the conn if the version extracted from conn isn't found" do
      conn = conn("invalid_version!")
      transformed_conn = PhoenixApiVersions.Plug.call(conn, nil)

      assert %Conn{
        halted: true,
        status: 404,
        resp_body: "{\"error\": \"not_found\"}",
      } = transformed_conn
    end

    test "Sets conn.private.phoenix_api_versions_process_output? to true so that the View macro can intercept the output" do
      transformed_conn = PhoenixApiVersions.Plug.call(conn("version1"), nil)

      assert %Conn{private: %{phoenix_api_versions_process_output?: true}} = transformed_conn
    end

    test "Applies changes from Change modules in the given order" do
      transformed_conn = PhoenixApiVersions.Plug.call(conn("version1"), nil)
    end

    test "Does not apply Change modules that do not return the request route in routes/1" do
      conn = conn("version1", MatchedController, :action_only_caught_by_v1_change_b)
      transformed_conn = PhoenixApiVersions.Plug.call(conn, nil)
    end
  end
end
