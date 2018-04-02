use Mix.Config

if Mix.env === :test do
  config :phoenix_api_versions, versions: PhoenixApiVersions.PlugTest.TestVersions
end
