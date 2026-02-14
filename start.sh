#!/bin/bash
cd ~/clawdeck
export SOLID_QUEUE_IN_PUMA=1
while true; do
  echo "[$(date)] Starting ClawDeck (SolidQueue embedded)..."
  bin/rails server -b 0.0.0.0 -p 4001 2>&1 | tee -a /tmp/clawdeck.log
  echo "[$(date)] ClawDeck died, restarting in 3s..."
  sleep 3
done
