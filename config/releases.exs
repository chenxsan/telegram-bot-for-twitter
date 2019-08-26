import Config

# Configures token for telegram bot
config :telegram_bot,
  token: System.fetch_env!("TELEGRAM_TOKEN")

# Configures extwitter oauth
config :extwitter, :oauth,
  consumer_key: System.fetch_env!("TWITTER_CONSUMER_KEY"),
  consumer_secret: System.fetch_env!("TWITTER_CONSUMER_SECRET")

config :tweet_bot, TweetBotWeb.Endpoint, secret_key_base: System.fetch_env!("SECRET_KEY_BASE")

# Configure your database
config :tweet_bot, TweetBot.Repo,
  username: System.fetch_env!("DATABASE_USER"),
  password: System.fetch_env!("DATABASE_PASS"),
  database: System.fetch_env!("DATABASE_NAME"),
  hostname: System.fetch_env!("DATABASE_HOST")
