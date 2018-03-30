defmodule PhoenixApiVersions.Version do
  @moduledoc """
  A struct representing a distinct version of a JSON API in a Phoenix application.

  ## `name`

  The `name` of a `Version` is very important.

  When a consumer visits a version of a JSON API (say "v2"), PhoenixApiVersions
  will not recognize unless the `name` exactly matches what is returned by the
  Versions module in the `c:PhoenixApiVersions.version_name/1` callback.
  """

  @enforce_keys [:name, :changes]

  defstruct name: nil,
            changes: []

  @type t :: %__MODULE__{
          name: String.t() | atom,
          changes: [module]
        }
end
