# Architectural Analysis: Vault Dynamic Secrets Engine vs. Traditional Secrets

## 1. Problem Statement: The Flaws of Static Secrets
In traditional Kubernetes deployments, secrets are injected as environment variables or mounted files sourced from base64-encoded Kubernetes Secret objects.
Even when encrypted in Git (using Mozilla SOPS, Bitnami Sealed Secrets, or AWS KMS):
1. **The Secret is Long-Lived:** The underlying database password remains static until an engineer manually runs an update script.
2. **Blast Radius is High:** If an application pod is breached via SSRF or RCE, the stolen database credentials allow indefinite access to the database.
3. **Audit Trails are Missing:** The database log shows all queries originating from a shared user (e.g. `webapp_prod`), making forensic attribution impossible.

## 2. Dynamic Secret Architecture
With HashiCorp Vault's Database Secrets Engine:
1. When an application demands credentials, Vault connects to PostgreSQL via a privileged admin connection.
2. Vault executes:
   ```sql
   CREATE ROLE "v-token-webapp-ro-..." WITH LOGIN PASSWORD '...' VALID UNTIL '2026-10-28 23:45:00';
   GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "v-token-webapp-ro-...";
   ```
3. A unique user is generated per lease.
4. When the lease expires or is revoked, Vault executes:
   ```sql
   DROP ROLE "v-token-webapp-ro-...";
   ```
5. If an attacker dumps the memory or environment of a compromised container, that credential becomes dead within minutes or hours.

## 3. Tool Comparison: ESO vs Vault Agent vs CSI Driver

| Feature | External Secrets Operator (ESO) | Vault Agent Sidecar | Vault CSI Secret Store |
| :--- | :--- | :--- | :--- |
| **Pod Resource Overhead** | **Zero sidecars** (Centralized controller) | High (1 sidecar container per pod) | Low (daemonset) |
| **Developer Complexity** | **None** (Consumes standard native K8s Secret) | Custom templates & annotations required | Requires volume mount manifests |
| **Support for Legacy Apps**| **100% Native** | Requires file reading or reload hooks | Requires file reading |
| **Secret Storage Location**| Native K8s Secret (etcd) | Memory / Pod ephemeral volume | Memory / Pod ephemeral volume |
| **GitOps Cleanliness** | 100% Declarative YAML in Git | Annotations in Deployment | Volume mounts in Deployment |
