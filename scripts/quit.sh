#!/usr/bin/env bash
#
# Quits a running MenuBarKit and waits until it's gone, so `open` starts the new
# build instead of re-activating the old process.
#
pkill -x MenuBarKit 2>/dev/null || exit 0
for _ in $(seq 50); do
  pgrep -x MenuBarKit >/dev/null || exit 0
  sleep 0.1
done
pkill -9 -x MenuBarKit 2>/dev/null || true
