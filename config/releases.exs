import Config

# Configures token for telegram bot
config :telegram_bot,
  token: System.get_env("TELEGRAM_TOKEN")

# Configures extwitter oauth
config :extwitter, :oauth,
  consumer_key: System.get_env("TWITTER_CONSUMER_KEY"),
  consumer_secret: System.get_env("TWITTER_CONSUMER_SECRET")

config :tweet_bot, TweetBotWeb.Endpoint, secret_key_base: System.get_env("SECRET_KEY_BASE")

# Configure your database
config :tweet_bot, TweetBot.Repo,
  username: System.get_env("DATABASE_USER"),
  password: System.get_env("DATABASE_PASS"),
  database: System.get_env("DATABASE_NAME"),
  hostname: System.get_env("DATABASE_HOST"),
  pool_size: 3,
  show_sensitive_data_on_connection_error: true
