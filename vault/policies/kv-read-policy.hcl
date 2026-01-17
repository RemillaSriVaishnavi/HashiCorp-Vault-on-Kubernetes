# Read-only access to KV v2 secrets for application configuration
path "secret/data/app/*" {
  capabilities = ["read", "list"]
}
