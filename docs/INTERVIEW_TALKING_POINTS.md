# SRE & DevOps Interview Deep-Dive: Lab 7

### Question 1: How do you achieve "Zero Secrets in Git" in a strict GitOps CI/CD workflow?
**Answer:**
"In our GitOps repository, we never commit secret values or encryption keys. Instead, we use declarative reference CRDs provided by the External Secrets Operator (`SecretStore` and `ExternalSecret`). Git only contains metadata describing *where* the secret lives in HashiCorp Vault (path and key) and the synchronization refresh interval. The External Secrets Operator authenticates directly with Vault using its Kubernetes ServiceAccount token, pulls the dynamically generated database credentials, and writes them to a native Kubernetes Secret inside the cluster boundary."

### Question 2: What is the failure scenario if HashiCorp Vault goes down?
**Answer:**
"With External Secrets Operator, when Vault experiences downtime or network partitions:
1. **Existing Pods Continue Operating:** The generated Kubernetes Secrets already exist in `etcd` and remain valid until their lease expires.
2. **Re-sync Retries with Exponential Backoff:** ESO will fail the sync step and emit an event/metric without deleting the existing target secret.
3. **High-Availability Vault:** In production, Vault runs in a clustered HA configuration with Raft consensus storage across multiple availability zones to prevent single points of failure."

### Question 3: Why choose External Secrets Operator over Vault Agent Injector sidecars?
**Answer:**
"Vault Agent Injector adds an additional container to every single application pod, which consumes CPU/memory overhead, adds init container latency to pod startup, and complicates sidecar termination during zero-downtime rolling updates. ESO is a single cluster-wide operator (or namespace-scoped operator) that uses native Kubernetes Secret primitives, allowing developers to consume standard environment variables without altering application code or Docker entrypoints."
