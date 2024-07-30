# Pubky Deploy

One click setup to run locally the full Pubky development stack. Runs a `backend` container (initial JS based indexer from `skunk-works`) and a `web` container from the `social-ui-monorepo` on development/watcher mode.

Create your own secret/pub Pkarr keys. You can use app.pkarr.org . Place them in a new `.env` file following the example template `cp .env-sample .env`. Then:

```
docker compose up
```

This repo uses `skunk-works` and `social-ui-monorepo` as Git submodules as these do not have Dockerfiles themselves yet.


## Submodules

Install submodules with:

```bash
# you can sync it with the main repo
git submodule sync

# you can update it with the main repo
git submodule update --init --recursive
```