#!/bin/sh
set -e

echo "Running Vault HA verification..."
vault status | grep "HA Enabled: true"

echo "Verifying Kubernetes auth..."
vault auth list | grep kubernetes

echo "Verifying KV v2 secret read..."
vault kv get secret/app/config

echo "Verifying database dynamic credentials..."
vault read database/creds/app-role

echo "Verifying transit encryption..."
PLAINTEXT=$(echo -n "test-data" | base64)
CIPHER=$(vault write -field=ciphertext transit/encrypt/my-encryption-key plaintext=$PLAINTEXT)
vault write transit/decrypt/my-encryption-key ciphertext=$CIPHER > /dev/null

echo "Verifying audit device..."
vault audit list | grep file

echo "ALL TESTS PASSED"
