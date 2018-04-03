# PhoenixApiVersions

> ### Move your API forward. Support legacy versions with ease.
> PhoenixApiVersions helps Phoenix JSON API apps support legacy versions while minimizing maintenance overhead.

[![Master](https://travis-ci.org/smartrent/phoenix_api_versions.svg?branch=master)](https://travis-ci.org/smartrent/phoenix_api_versions)
[![Hex.pm Version](http://img.shields.io/hexpm/v/phoenix_api_versions.svg?style=flat)](https://hex.pm/packages/phoenix_api_versions)
[![Coverage Status](https://coveralls.io/repos/github/smartrent/phoenix_api_versions/badge.svg?branch=master)](https://coveralls.io/github/smartrent/phoenix_api_versions?branch=master)

## Documentation

API documentation is available at [https://hexdocs.pm/phoenix_api_versions](https://hexdocs.pm/phoenix_api_versions)

## How Does It Work?

### It's A JSON Translation Layer

PhoenixApiVersions simply does the following:

1. Modifies incoming JSON before it reaches the controller
2. Modifies outgoing JSON right before sending the response

### Versions Are Defined In Layers

```
-------------
|           |
|    v3     |
|           |
| (current) |
|           |
|     ▲     |
------|------  <-- v2/v3 translation layer
|     ▼     |
|           |
|    v2     |
|           |
|     ▲     |
------|------  <-- v1/v2 translation layer
|     ▼     |
|           |
|    v1     |
|           |
|           |
-------------
```

Each legacy version is responsible for transforming JSON to and from the shape expected/returned by the next version. **Apart from bug fixes, developers will only have to maintain middleware from the last version.**

Assume an API whose **current version is v3**.

- v1 middleware transforms incoming JSON to the shape that v2 expects.
- v2 middleware transforms incoming JSON to the shape that v3 expects.

The request reaches the controller in the shape of the current version. The controller and view respond with "v3 JSON".

- v2 middleware transforms outgoing v3 JSON to the shape that v2 should return.
- v1 middleware then transforms the v2 JSON to the shape that v1 should return.

Once v4 comes out, developers will simply build the transformation layer for v3-to-v4 (and back).

### Supports Any Versioning Mechanism

The version can be specified in any way:

- URL (`/api/v1/...`)
- Accept header (`Accept: application/vnd.github.v3.json`)
- Custom header (`X-Api-Version: 2016-01-20`)
- Anything else in `conn`

### Benefits

#### ✅ Limits Legacy Code

PhoenixApiVersions only allows developers to define old versions by **transforming JSON**.

It assumes that these JSON-transforming middleware functions will not perform database calls or heavy computation. (Although this is not completely prohibited.)

#### ✅ Flexible

If your application has one or two legacy API endpoints that simply need to be handled differently, that's completely posslble.

#### ✅ Ensure Consistent Business Rules Across API Versions

Every version of a given API endpoint will reach the same controller function, making it much less likely that subtle differences between business rules will crystallize over time.

## Installation

### Add PhoenixApiVersions To `web.ex`

In the Phoenix `web.ex` file for your JSON API, add the plug to the `controller` section, and `use` the PhoenixApiVersions view macro in the `view` section.

Optionally, you may want to add a `render("404.json", _)` function in the `view` section, which can be used later if you don't already have a mechanism for handling 404's.

```elixir
# web.ex

def controller do
  quote do

    plug PhoenixApiVersions.Plug

  end
end

def view do
  quote do

    use PhoenixApiVersions.View


    # Optional; recommended if you have no other way to handle 404's yet
    def render("404.json", _) do
      %{error: "not_found"}
    end

  end
end
```

### Create an ApiVersions Module

We suggest calling this `ApiVersions`, namespaced inside your phoenix application's main namespace. (e.g. `MyApp.ApiVersions`) Make sure to `use PhoenixApiVersions` in this module.

The module must implement the `PhoenixApiVersions` behaviour, which includes `version_not_found/1`, `version_name/1`, and `versions/0`.

#### Example

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

### Add ApiVersions Module in `config.exs`

Reference this module in your Phoenix application's `config.exs` as such:

```elixir
config :phoenix_api_versions, versions: MyApp.ApiVersions
```

### Add Change Modules

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

  def transform_request_body_params(%{"name" => _} = params, DeviceController, action)
      when action in [:create, :update] do
    params
    |> Map.put("description", params["name"])
    |> Map.drop(["name"])
  end

  def transform_response(%{data: device} = output, DeviceController, action)
      when action in [:create, :update, :show] do
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
