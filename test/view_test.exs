defmodule PhoenixApiVersions.ViewTest do
  use ExUnit.Case, async: true

  alias Plug.Conn

  defmodule WidgetView do
    use PhoenixApiVersions.View

    def render("index.json", %{widgets: widgets}) do
      %{data: widgets}
    end

    def render("show.json", %{widget: widget}) do
      %{data: widget}
    end
  end

  defmodule WidgetController do
  end

  defmodule V1.IdentifierToName do
    use PhoenixApiVersions.Change

    # The View macro is not responsible for filtering out change modules using routes/0
    def routes, do: []

    def transform_response(%{data: data} = response, WidgetController, :index) do
      transformed_data =
        data
        |> Enum.map(& %{name: &1.identifier})

      response
      |> Map.put(:data, transformed_data)
    end

    def transform_response(%{data: data} = response, WidgetController, :show) do
      transformed_data =
        data
        |> Map.put(:name, data.identifier)
        |> Map.drop([:name])

      response
      |> Map.put(:data, transformed_data)
    end

    def transform_response(%{data: _data}, WidgetController, :create) do
      raise "This match should never be reached!"
    end
  end

  defmodule V2.DescriptionToIdentifier do
    use PhoenixApiVersions.Change

    # The View macro is not responsible for filtering out change modules using routes/0
    def routes, do: []

    def transform_response(%{data: data} = response, WidgetController, :index) do
      transformed_data =
        data
        |> Enum.map(& %{identifier: &1.description})

      response
      |> Map.put(:data, transformed_data)
    end

    def transform_response(%{data: data} = response, WidgetController, :show) do
      transformed_data =
        data
        |> Map.put(:identifier, data.description)
        |> Map.drop([:description])

      response
      |> Map.put(:data, transformed_data)
    end
  end

  def assigns(action) do
    private = %{
      phoenix_controller: WidgetController,
      phoenix_action: action
    }
    |> Map.put(PhoenixApiVersions.private_process_output_key(), true)
    |> Map.put(PhoenixApiVersions.private_changes_key(), [
      V1.IdentifierToName,
      V2.DescriptionToIdentifier
    ])

    conn =
      %Conn{private: private}

    %{conn: conn}
  end

  describe "PhoenixApiVersions.View" do
    setup do
      widgets = [
        %{description: "foo"},
        %{description: "bar"},
        %{description: "baz"}
      ]

      {:ok, %{widgets: widgets}}
    end
    test "Applies all applicable changes in reverse order defined in conn.private.phoenix_api_versions_changes", %{widgets: widgets} do
      output = WidgetView.render(
        "index.json",
        Map.put(assigns(:index), :widgets, widgets)
      )

      assert %{data: [
        %{name: "foo"},
        %{name: "bar"},
        %{name: "baz"}
      ]} = output
    end

    test "Does not apply changes is conn.private.phoenix_api_versions_process_output? is not true", %{widgets: widgets} do
      %{conn: conn} = assigns(:index)

      conn =
        conn
        |> Map.put(:private, Map.drop(conn.private, [:phoenix_api_versions_process_output?]))

      output = WidgetView.render("index.json", %{conn: conn, widgets: widgets})

      assert %{data: [
        %{description: "foo"},
        %{description: "bar"},
        %{description: "baz"}
      ]} = output
    end
  end
end
