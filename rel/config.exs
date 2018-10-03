# Import all plugins from `rel/plugins`
# They can then be used by adding `plugin MyPlugin` to
# either an environment, or release definition, where
# `MyPlugin` is the name of the plugin module.
~w(rel plugins *.exs)
|> Path.join()
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

use Mix.Releases.Config,
  # This sets the default release built by `mix release`
  default_release: :default,
  # This sets the default environment used by `mix release`
  default_environment: Mix.env()

# For a full list of config options for both releases
# and environments, visit https://hexdocs.pm/distillery/config/distillery.html

# You may define one or more environments in this file,
# an environment's settings will override those of a release
# when building in that environment, this combination of release
# and environment configuration is called a profile

environment :dev do
  # If you are running Phoenix, you should make sure that
  # server: true is set and the code reloader is disabled,
  # even in dev mode.
  # It is recommended that you build with MIX_ENV=prod and pass
  # the --env flag to Distillery explicitly if you want to use
  # dev mode.
  set(dev_mode: true)
  set(include_erts: false)
  set(cookie: :"/fcFg1%q{q!WKUXOsa&kwV3CEl)RP(u5l>^67EvB1w%iThFy;,,!X*dMWvFMp!4c")
end

environment :prod do
  set(include_erts: true)
  set(include_src: false)
  set(cookie: :"p=$dC[$t:@5>z^yex}K}(M[U4p{V&~X~Is(bR{4sSDr5|g@K>;]O{(zHWQU<4El0")
end

# You may define one or more releases in this file.
# If you have not set a default release, or selected one
# when running `mix release`, the first release in the file
# will be used by default

release :tweet_bot do
  set(version: current_version(:tweet_bot))

  set(
    applications: [
      :runtime_tools
    ]
  )

  set(
    config_providers: [
      {Mix.Releases.Config.Providers.Elixir, ["${RELEASE_ROOT_DIR}/etc/config.exs"]}
    ]
  )

  set(
    commands: [
      migrate: "rel/commands/migrate.sh",
      seed: "rel/commands/seed.sh"
    ]
  )

  set(
    overlays: [
      {:copy, "config/prod.exs", "etc/config.exs"}
    ]
  )

  set(pre_start_hooks: "rel/hooks/pre_start")
end
