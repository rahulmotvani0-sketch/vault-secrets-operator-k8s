.PHONY: help setup-cluster deploy-vault deploy-app verify clean

help:
	@echo "Available commands:"
	@echo "  make setup-vault  - Install Vault, ESO, Postgres, and wire dynamic DB auth"
	@echo "  make deploy-app   - Apply SecretStore, ExternalSecret, and sample consumer API"
	@echo "  make verify       - Verify dynamic credentials, inspect pods, and audit zero secrets in Git"
	@echo "  make clean        - Delete resources and test namespaces"

setup-vault:
	chmod +x scripts/*.sh
	./scripts/setup-vault.sh

deploy-app:
	kubectl apply -f k8s/external-secrets/secret-store.yaml
	kubectl apply -f k8s/external-secrets/external-secret.yaml
	@echo "Waiting for ExternalSecret to synchronize..."
	sleep 5
	kubectl apply -f k8s/app/deployment.yaml
	kubectl rollout status deployment/secured-api --timeout=60s

verify:
	chmod +x scripts/*.sh
	./scripts/verify-zero-secrets.sh

clean:
	kubectl delete -f k8s/app/deployment.yaml --ignore-not-found
	kubectl delete -f k8s/external-secrets/ --ignore-not-found
	kubectl delete -f k8s/postgres/postgres.yaml --ignore-not-found
	helm uninstall vault -n vault --ignore-not-found
	helm uninstall external-secrets -n external-secrets --ignore-not-found
	kubectl delete ns vault external-secrets database --ignore-not-found
