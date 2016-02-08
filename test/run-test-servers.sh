#!/bin/bash
#
# Copyright 2016 Apcera Inc. All rights reserved.
#
# Simple script to start up a set of gnatsd servers on a known set of ports
# for our integration tests. Trying to controll all this in elixir vs.
# the shell (for now) is a hack.
#
# This is expected to be run from the project's root directory. See notes on
# ports (below).
#
# FIXME: jam: test on windows and other platforms (or adapt?)
#

#set -xv

ME="`basename $0`"
DEFAULT_GNATSD=gnatsd
#DEFAULT_GNATSD=go run gnatsd.go
GNATSD=${*:-$DEFAULT_GNATSD}

check_gnatsd() {
  echo "$ME: unable to find GNATSD executable: $1" >&2
  echo "$ME: ensure its in your PATH or pass it explicitly to this script" >&2
  exit 1
}

run_gnats() {
    echo "$ME: starting NATS server: $@"
    $@ < /dev/null 2>&1 &

#check_gnatsd
    
}

echo "$ME: starting NATS servers... (hit ^C or kill this job to stop servers)"
# NOTES on servers and ports for tests...
# these are all set to run on specific ports till someone gets around
# to automating all the tests to start/stop/kill! servers on specific ports
# within elixir. till then this script is a wrapper :-(
run_gnats $GNATSD -c test/conf/plain.conf
run_gnats $GNATSD -c test/conf/auth.conf
run_gnats $GNATSD -c test/conf/tls.conf
wait
