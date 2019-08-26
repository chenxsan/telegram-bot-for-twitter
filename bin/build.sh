#!/usr/bin/env bash

set -e

cd /opt/build/app

APP_NAME="$(grep 'app:' mix.exs | sed -e 's/\[//g' -e 's/ //g' -e 's/app://' -e 's/[:,]//g')"
APP_VSN="$(grep 'version:' mix.exs | cut -d '"' -f2)"

export MIX_ENV=prod

# Fetch deps and compile
mix deps.get --only prod
# Run an explicit clean to remove any build artifacts from the host
mix do clean, compile --force
cd ./assets
npm install
npm run deploy
cd ..
mix phx.digest
# Build the release
mix release

# Copy tarball to output
# cp "_build/prod/rel/$APP_NAME/releases/$APP_VSN/$APP_NAME.tar.gz" rel/artifacts/"$APP_NAME-$APP_VSN.tar.gz"

exit 0