#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo " [Step 1/4] Ensuring Helm Repositories & Namespaces"
echo "=========================================================="
helm repo add hashicorp https://helm.releases.hashicorp.com --force-update
helm repo add external-secrets https://charts.external-secrets.io --force-update
helm repo update

kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -

echo "=========================================================="
echo " [Step 2/4] Deploying Postgres Database Target"
echo "=========================================================="
kubectl apply -f k8s/postgres/postgres.yaml
kubectl rollout status deployment/postgres -n database --timeout=120s

echo "=========================================================="
echo " [Step 3/4] Installing HashiCorp Vault & External Secrets"
echo "=========================================================="
helm upgrade --install vault hashicorp/vault \
  --namespace vault \
  -f k8s/vault/vault-values.yaml

kubectl rollout status deployment/vault -n vault --timeout=120s

helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --set installCRDs=true

kubectl rollout status deployment/external-secrets -n external-secrets --timeout=120s

echo "=========================================================="
echo " [Step 4/4] Configuring Vault Database & K8s Auth Engines"
echo "=========================================================="
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath="{.items[0].metadata.name}")

# Copy policy to Vault pod
kubectl cp k8s/vault/vault-policy.hcl vault/${VAULT_POD}:/tmp/vault-policy.hcl

kubectl exec -n vault "${VAULT_POD}" -- env VAULT_TOKEN=root-master-token sh -c '
  export VAULT_ADDR="http://127.0.0.1:8200"

  # Enable Database Secrets Engine
  vault secrets enable database || true

  # Connect Vault to Postgres Database
  vault write database/config/postgresql \
    plugin_name="postgresql-database-plugin" \
    connection_url="postgresql://{{username}}:{{password}}@postgres.database.svc.cluster.local:5432/appdb?sslmode=disable" \
    username="vaultadmin" \
    password="vaultadminmasterpassword123" \
    allowed_roles="webapp-role"

  # Configure dynamic role with 1h TTL and automatic user revocation
  vault write database/roles/webapp-role \
    db_name="postgresql" \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '\''{{password}}'\'' VALID UNTIL '\''{{expiration}}'\''; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

  # Enable Kubernetes Auth Method
  vault auth enable kubernetes || true

  vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443"

  # Write Policy
  vault policy write webapp-policy /tmp/vault-policy.hcl

  # Bind ESO service account to policy
  vault write auth/kubernetes/role/webapp-eso-role \
    bound_service_account_names=external-secrets \
    bound_service_account_namespaces=external-secrets \
    policies=webapp-policy \
    ttl=1h
'

echo "=========================================================="
echo " Vault and External Secrets Operator Successfully Wired! "
echo " Now run: make deploy-app"
echo "=========================================================="
