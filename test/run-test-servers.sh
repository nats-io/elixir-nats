#!/bin/bash
#
# Copyright 2016 Apcera Inc. All rights reserved.
#
# Simple script to start up a set of gnatsd servers on a known set of ports
# for our integration tests. Trying to controll all this in elixir vs.
# the shell (for now) is a hack.
#
# This is expected to be run from the project's root directory

ME="`basename $0`"
GNATSD=gnatsd


run_gnats() {
  echo "$ME: starting NATS server with config: $1"
  echo "$GNATSD" -c "./test/conf/$1" < /dev/null > /dev/null 2>&1 &
}

# default server... no config
run_gnats plain.conf
run_gnats auth.conf
run_gnats tls.conf
