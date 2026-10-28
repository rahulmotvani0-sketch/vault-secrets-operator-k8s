# Policy allowing External Secrets Operator to generate dynamic database credentials
path "database/creds/webapp-role" {
  capabilities = ["read"]
}

# Policy to allow reading KV secrets if needed
path "secret/data/*" {
  capabilities = ["read"]
}
