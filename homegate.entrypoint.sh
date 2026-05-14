#!/bin/sh

set -eu

mkdir -p /data
cp /config.toml /data/config.toml

exec homegate --data-dir /data
