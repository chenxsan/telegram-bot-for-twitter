# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :tweet_bot,
  ecto_repos: [TweetBot.Repo]

# Configures the endpoint
config :tweet_bot, TweetBotWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "hLANbXMahFIMbsvWL363rXGHPhxMz0gy01IN5pmhEhirz7CMQySyKgM02o9ek9oS",
  render_errors: [view: TweetBotWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: TweetBot.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
