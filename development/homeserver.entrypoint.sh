#!/bin/sh

# Check the NETWORK environment variable and execute the appropriate command
if [ "$NETWORK" = "mainnet" ]; then
  exec homeserver --config=/config.toml -t pubky_homeserver=info,tower_http=info
else
  exec testnet --config=/config.toml -t pubky_homeserver=info,tower_http=info
fi
