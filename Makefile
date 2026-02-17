COMPOSE = docker compose -f docker-compose.yml -f docker-compose.extra.yml
BASE_IMAGE ?= openclaw:local

.PHONY: start cli root build build-base clawhub

start:
	$(COMPOSE) up -d

build-base:
	docker build -t $(BASE_IMAGE) .

build: build-base
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
