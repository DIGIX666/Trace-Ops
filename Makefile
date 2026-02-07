PROJECT_NAME ?= TRACE-OPS

KEYCLOAK_DOCKER_PATH = ./keycloak-config/docker-compose.keycloak.yml
COMPOSE_Z1 = zone1/docker-compose.yml
COMPOSE_Z2 = zone2-ledger/compose/docker-compose.yaml

.PHONY: help z1-up z1-build z1-down z1-stop z1-logs z1-clean z1-ps z2-up z2-down z2-clean z2-bootstrap

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

z1-up:
	docker compose -f $(ZONE1_DOCKER_PATH) up -d

z1-build:
	docker compose -f "$(ZONE1_DOCKER_PATH)" build --no-cache
	docker compose -f "$(ZONE1_DOCKER_PATH)" up -d

z1-down:
	docker compose -f $(ZONE1_DOCKER_PATH) down

z1-stop:
	docker compose -f $(ZONE1_DOCKER_PATH) stop

z1-logs:
	docker compose -f $(ZONE1_DOCKER_PATH) logs -f

z1-clean: down
	docker compose -f $(ZONE1_DOCKER_PATH) down -v
	docker system prune -f

z1-ps:
	docker compose -f $(ZONE1_DOCKER_PATH) ps

z2-up:
	docker compose -f $(COMPOSE_Z2) up -d

z2-down:
	docker compose -f $(COMPOSE_Z2) down -v

z2-clean:
	@echo "Nettoyage des volumes et des certificats..."
	docker compose -f $(COMPOSE_Z2) down -v
	sudo rm -rf zone2-ledger/crypto/ca/*
	sudo rm -rf zone2-ledger/crypto/organizations/*
	sudo rm -rf zone2-ledger/crypto/channel-artifacts/*

z2-bootstrap:
	@echo "Lancement du bootstrap Zone 2..."
	chmod +x zone2-ledger/scripts/*.sh
	cd zone2-ledger/scripts && sudo ./bootstrap-network.sh

z2-generate-connection-profiles:
	cd zone2-ledger/scripts && sudo ./generate-connection-profiles.sh

z2-deploy-chaincode:
	cd zone2-ledger/scripts && ./deploy-chaincode.sh
