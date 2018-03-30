# PhoenixApiVersions

PhoenixApiVersions helps Phoenix applications support multiple JSON API versions while minimizing maintenance overhead.

## Documentation

API documentation is available at [https://hexdocs.pm/phoenix_api_versions](https://hexdocs.pm/phoenix_api_versions)

## Getting Started

### Adding PhoenixApiVersions To Your Project

In the Phoenix `web.ex` file for your JSON API, add the plug to the `controller` section, and `use` the PhoenixApiVersions view macro in the `view` section.

Optionally, you may want to add a `render("404.json", _)` function in the `view` section, which can be used later if you don't already have a mechanism for handling 404's.

```elixir
# web.ex

def controller do
  quote do
    # ...

    plug PhoenixApiVersions.Plug

    # ...
  end
end

def view do
  quote do
    # ...

    use PhoenixApiVersions.View

    def render("404.json", _) do
      %{error: "not_found"}
    end

    # ...
  end
end
```

### Creating an ApiVersions Module

Create a configuration module. We suggest calling this `ApiVersions`, namespaced inside your phoenix application's main namespace. (e.g. `MyApp.ApiVersions`)

Make sure to `use PhoenixApiVersions` in this module.

The module must implement the `PhoenixApiVersions` behaviour, which includes `version_not_found/1`, `version_name/1`, and `versions/0`.

```elixir
# lib/my_app_web/api_versions/api_versions.ex

defmodule MyApp.ApiVersions do
  use PhoenixApiVersions

  alias PhoenixApiVersions.Version
  alias MyApp.ApiVersions.V1
  alias Plug.Conn
  alias Phoenix.Controller

  def version_not_found(conn) do
    conn
    |> Conn.put_status(:not_found)
    |> Controller.render("404.json", %{})
  end

  def version_name(conn) do
    Map.get(conn.path_params, "api_version")
  end

  def versions do
    [
      %Version{
        name: "v1",
        changes: [
          V1.ChangeNameToDescription,
          V1.AnotherChange
        ]
      },
      %Version{
        name: "v2",
        changes: []
      }
    ]
  end
end
```

### Creating Change Modules

Change modules are only used when the current route is found in `routes/1`.

#### Example

Assume your project has a concept of `devices`, each with a `name` property. In version `v2`, you want to change `name` to `description`.

Simply change all your code (and the database field) to `description`. Then, implement a change like this:

```elixir
# lib/my_app_web/api_versions/v1/change_name_to_description.ex

defmodule MyApp.ApiVersions.V1.ChangeNameToDescription do
  use PhoenixApiVersions.Change

  alias MyApp.Api.DeviceController

  def routes do
    [
      {DeviceController, :show},
      {DeviceController, :create},
      {DeviceController, :update},
      {DeviceController, :index}
    ]
  end

  def transform_request_body_params(%{"name" => _} = params, DeviceController, action) when action in [:create, :update] do
    params
    |> Map.put("description", params["name"])
    |> Map.drop(["name"])
  end

  def transform_response(%{data: device} = output, DeviceController, action) when action in [:create, :update, :show] do
    output
    |> Map.put(:data, device_output_to_v1(device))
  end

  def transform_response(%{data: devices} = output, DeviceController, :index) do
    devices = Enum.map(devices, &device_output_to_v1/1)

    output
    |> Map.put(:data, devices)
  end

  defp device_output_to_v1(device) do
    device
    |> Map.put(:name, device.description)
    |> Map.drop([:description])
  end
end
```

As a result, `v1` API endpoints will accept and return the field as `name`, while `v2` API endpoints will accept and return is as `description`.

## Credits

The inspiration for this library came from two sources:

- Stripe's API versioning scheme [revealed in this blog](https://stripe.com/blog/api-versioning).
- [This Hacker News comment](https://news.ycombinator.com/item?id=16445698) by [bringtheaction](https://news.ycombinator.com/user?id=bringtheaction) which references an idea from a [Rich Hickey talk](https://www.youtube.com/watch?v=oyLBGkS5ICk) about "maintaining old versions not by backporting bug fixes but instead by rewriting the old version to be a thin layer that gives you the interface of the old version upon the code of the new version."

## License

This software is licensed under [the MIT license](LICENSE.md).
