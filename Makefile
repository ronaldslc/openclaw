COMPOSE = docker compose -f docker-compose.yml -f docker-compose.extra.yml

.PHONY: start cli root build clawhub

start:
	$(COMPOSE) up -d

build:
	$(COMPOSE) build

cli:
	$(COMPOSE) exec openclaw-gateway node dist/index.js $(filter-out $@,$(MAKECMDGOALS))

clawhub:
	$(COMPOSE) exec openclaw-gateway npx clawhub $(filter-out $@,$(MAKECMDGOALS))

root:
	$(COMPOSE) exec -u root openclaw-gateway bash

node: 
	$(COMPOSE) exec -u node openclaw-gateway bash

# Catch-all rule to prevent "No rule to make target" for arguments
%:
	@:
