# Install

1. Create `$HOME/openclaw_home`
2. Run `setup-advanced.sh` (not tested from scratch)

Reference: https://docs.openclaw.ai/install/docker

When configuring...

1. Keep network mode on `loopback`, then don't use the CLI docker compose service, because it is on a different docker IP.
2. Use this for pairing with web console `docker compose exec openclaw-gateway node dist/index.js devices list`
3. Approve `docker compose exec openclaw-gateway node dist/index.js devices approve 6f9db1bd-a1cc-4d3f-b643-2c195262464e`

You can use the Makefile shortcuts

- `make cli devices list`
- `make build`
- `make start`
- `make clawhub`

etc...
