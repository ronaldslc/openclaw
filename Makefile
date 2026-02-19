COMPOSE = docker compose -f docker-compose.yml -f docker-compose.extra.yml
BASE_IMAGE ?= openclaw:local

# Load environment variables from .env.extra if it exists
ifneq (,$(wildcard ./.env.extra))
    include .env.extra
    export
endif

# Default for OPENCLAW_HOME if not set in .env.extra or environment
OPENCLAW_HOME ?= $(HOME)/openclaw_home

.PHONY: help start cli root build build-base build-sandboxes clawhub restart

help:
	@echo "Available commands:"
	@echo "  make start            - Start the gateway (detached)"
	@echo "  make restart          - Restart the gateway and recreate all sandboxes"
	@echo "  make build            - Build the gateway image and extract skills"
	@echo "  make build-sandboxes  - Build the specialized sandbox images (tmux, coder)"
	@echo "  make cli -- [args]    - Run an OpenClaw CLI command"
	@echo "  make root             - Open a root shell in the gateway container"
	@echo "  make node             - Open a node user shell in the gateway container"

# NOTE: if you need to run flags inside the CLI command for example use `make cli -- command --help`

start:
	$(COMPOSE) up -d

restart:
	$(COMPOSE) up -d --force-recreate
	$(COMPOSE) exec openclaw-gateway node dist/index.js sandbox recreate --all --force

build-base:
	docker build -t $(BASE_IMAGE) .

build: build-base
	$(COMPOSE) build
	docker create --name tmp-skills-extract $(BASE_IMAGE) && \
	  docker cp tmp-skills-extract:/app/skills/. $(OPENCLAW_HOME)/bundled-skills/ && \
	  docker rm tmp-skills-extract || docker rm tmp-skills-extract

build-sandboxes:
	docker build -t openclaw-sandbox:bookworm-slim -f Dockerfile.sandbox .
	docker build -t openclaw-sandbox:tmux -f Dockerfile.sandbox-tmux .
	docker build -t openclaw-sandbox:coder -f Dockerfile.sandbox-coder .

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
