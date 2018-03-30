defmodule PhoenixApiVersions.Version do
  @enforce_keys [:name, :changes]

  defstruct name: nil,
            changes: []

  @type t :: %__MODULE__{
          name: String.t() | atom,
          changes: [module]
        }
end
