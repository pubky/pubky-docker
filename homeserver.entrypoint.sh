#!/bin/sh

# Check the NETWORK environment variable and execute the appropriate command
if [ "$NETWORK" = "mainnet" ]; then
  exec homeserver
else
  exec homeserver --homeserver-config=/config.toml
fi