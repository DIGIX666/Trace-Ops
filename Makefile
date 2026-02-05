PROJECT_NAME ?= TRACE-OPS
KEYCLOAK_DOCKER_PATH = ./keycloak-config/docker-compose.keycloak.yml
ZONE1_DOCKER_PATH = ./zone1/docker-compose.yml

.PHONY: help up build down stop logs clean keycloak-up keycloak-down app-up app-down

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

up:
	docker compose -f $(ZONE1_DOCKER_PATH) up -d

build:
	docker compose -f "$(ZONE1_DOCKER_PATH)" build --no-cache
	docker compose -f "$(ZONE1_DOCKER_PATH)" up -d

down:
	docker compose -f $(ZONE1_DOCKER_PATH) down

stop:
	docker compose -f $(ZONE1_DOCKER_PATH) stop

logs:
	docker compose -f $(ZONE1_DOCKER_PATH) logs -f

clean: down
	docker compose -f $(ZONE1_DOCKER_PATH) down -v
	docker system prune -f

ps:
	docker compose -f $(ZONE1_DOCKER_PATH) ps
