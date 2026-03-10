#!/bin/sh

echo "Vault Post Bootstrap Started..."

export VAULT_ADDR=http://kind:8200
export VAULT_TOKEN=$VAULT_ROOT_TOKEN

######################################
# WAIT FOR VAULT
######################################
until curl -s $VAULT_ADDR/v1/sys/health | grep -q '"initialized":true'; do
  echo "Waiting for Vault..."
  sleep 3
done

echo "Vault Ready!"

######################################
# ENABLE K8s AUTH
######################################
vault auth enable kubernetes || true

K8S_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.server}')

K8S_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 --decode)

TOKEN_REVIEW_JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

vault write auth/kubernetes/config \
  token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
  kubernetes_host="$K8S_HOST" \
  kubernetes_ca_cert="$K8S_CA_CERT"

######################################
# ENABLE KV V2
######################################
vault secrets enable -path=secret -version=2 kv || true

vault kv put secret/app/config \
  username="demo" \
  password="demo123"

######################################
# CREATE K8S SECRET FROM VAULT
######################################

echo "Creating K8s Secret from Vault..."

kubectl create secret generic postgres-admin-secret \
  --from-literal=POSTGRES_USER=vaultadmin \
  --from-literal=POSTGRES_PASSWORD=$DB_ADMIN_PASS \
  --dry-run=client -o yaml | kubectl apply -f -

######################################
# GENERATE DB ADMIN PASSWORD
######################################

echo "Generating DB admin password..."

DB_ADMIN_PASS=$(openssl rand -base64 20)

vault kv put secret/db/admin \
  username="vaultadmin" \
  password="$DB_ADMIN_PASS"

######################################
# ENABLE DATABASE ENGINE
######################################
vault secrets enable database || true

vault write database/config/postgres-db \
  plugin_name=postgresql-database-plugin \
  allowed_roles="app-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/appdb?sslmode=disable" \
  username="vaultadmin" \
  password="$DB_ADMIN_PASS"

######################################
# CREATE DB ROLE (TTL 1H)
######################################
vault write database/roles/app-role \
  db_name=postgres-db \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

######################################
# ENABLE TRANSIT
######################################
vault secrets enable transit || true

vault write -f transit/keys/app-key

######################################
# ENABLE AUDIT
######################################
vault audit enable file file_path=/vault/logs/audit.log || true

######################################
# LOAD POLICIES
######################################
vault policy write kv-read-policy /vault/policies/kv-read-policy.hcl
vault policy write db-dynamic-policy /vault/policies/db-dynamic-policy.hcl

######################################
# CREATE VAULT ROLES
######################################
vault write auth/kubernetes/role/app-kv-role \
  bound_service_account_names=app-sa \
  bound_service_account_namespaces=default \
  policies=kv-read-policy \
  ttl=1h

vault write auth/kubernetes/role/app-db-role \
  bound_service_account_names=app-sa \
  bound_service_account_namespaces=default \
  policies=db-dynamic-policy \
  ttl=1h

echo "Vault Fully Configured!"