defmodule PhoenixApiVersions.ChangeTest do
  use ExUnit.Case, async: true

  defmodule TestChange do
    use PhoenixApiVersions.Change

    def routes do
      [
        {ExpectedControllerModule, :expected_controller_action}
      ]
    end

    def transform_request_body_params(body_params, ExpectedControllerModule, :expected_controller_action) do
      body_params
      |> Map.put("body", "overridden_body_value")
      |> Map.put("query", "in_body_not_query")
      |> Map.put("path", "in_body_not_path")
    end

    def transform_request_query_params(query_params, ExpectedControllerModule, :expected_controller_action) do
      query_params
      |> Map.put("body", "in_query_not_body")
      |> Map.put("query", "overridden_query_value")
      |> Map.put("path", "in_query_not_path")
    end

    def transform_request_path_params(path_params, ExpectedControllerModule, :expected_controller_action) do
      path_params
      |> Map.put("body", "in_path_not_body")
      |> Map.put("query", "in_path_not_query")
      |> Map.put("path", "overridden_path_value")
    end

    def transform_response(%{data: data}, ExpectedControllerModule, :expected_controller_action) do
      %{
        overridden_output: true,
        original_data: data
      }
    end
  end

  defmodule ChangeWithoutFunctionOverrides do
    def routes do
      [
        {ExpectedControllerModule, :expected_controller_action}
      ]
    end

    use PhoenixApiVersions.Change
  end

  def conn do
    %{
      private: %{
        phoenix_controller: ExpectedControllerModule,
        phoenix_action: :expected_controller_action
      },
      body_params: %{
        "body" => "original_value"
      },
      query_params: %{
        "query" => "original_value"
      },
      path_params: %{
        "path" => "original_value"
      },
      params: %{
        "body" => "original_value",
        "query" => "original_value",
        "path" => "original_value"
      }
    }
  end

  describe "PhoenixApiVersions.Change.transform_request/1" do
    test "Under the hood calls transform_request_body_params to transform body_params" do
      assert %{
        body_params: %{
          "body" => "overridden_body_value",
          "query" => "in_body_not_query",
          "path" => "in_body_not_path"
        }
      } = TestChange.transform_request(conn())
    end

    test "Under the hood calls transform_request_query_params to transform query_params" do
      assert %{
        query_params: %{
          "body" => "in_query_not_body",
          "query" => "overridden_query_value",
          "path" => "in_query_not_path"
        }
      } = TestChange.transform_request(conn())
    end

    test "Under the hood calls transform_request_path_params to transform path_params" do
      assert %{
        path_params: %{
          "body" => "in_path_not_body",
          "query" => "in_path_not_query",
          "path" => "overridden_path_value"
        }
      } = TestChange.transform_request(conn())
    end

    test "Merges transformed query/body/path params in that order (just like Phoenix's order) into conn.params" do
      assert %{
        params: %{
          "body" => "in_path_not_body",
          "query" => "in_path_not_query",
          "path" => "overridden_path_value"
        }
      } = TestChange.transform_request(conn())
    end

    test "transform_request_body_params, transform_request_query_params, and transform_request_path_params have default implementations that do no transformation" do
      assert %{
        body_params: %{
          "body" => "original_value"
        },
        query_params: %{
          "query" => "original_value"
        },
        path_params: %{
          "path" => "original_value"
        },
        params: %{
          "body" => "original_value",
          "query" => "original_value",
          "path" => "original_value"
        }
      } = ChangeWithoutFunctionOverrides.transform_request(conn())
    end
  end

  describe "PhoenixApiVersions.Change.transform_response/2" do
    test "Calls transform_response/3 with the output and controller module/action and returns the result" do
      output = %{data: :some_data}

      transformed_output = TestChange.transform_response(output, %{conn: conn()})

      assert %{
        overridden_output: true,
        original_data: :some_data
      } = transformed_output
    end

    test "transform_response/3 has a default implementation that does no transformation" do
      output = %{data: :some_data}
      transformed_output = ChangeWithoutFunctionOverrides.transform_response(output, %{conn: conn()})

      assert output === transformed_output
    end
  end
end
