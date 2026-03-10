#!/bin/sh

echo "Secret Rotation Monitor Started..."

while true
do
  echo "-----------------------------------"
  echo "Reading Latest Injected Secrets..."

  echo "KV Secret:"
  cat /vault/secrets/config

  echo ""

  echo "Dynamic DB Secret:"
  cat /vault/secrets/db-creds

  echo ""

  echo "Sleeping for 30 seconds..."
  sleep 30
done