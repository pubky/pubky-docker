# Pubky Docker

Run a local Pubky stack from source. The Pubky service images are built from local Git checkouts rather than pulled from the Docker registry, because the registry images are not currently the source of truth for local development.

This orchestration can run:

- [Pubky Homeserver](https://github.com/pubky/pubky-core/tree/main/pubky-homeserver), from `pubky/pubky-core`
- [Pubky Nexus](https://github.com/pubky/pubky-nexus), from `pubky/pubky-nexus`
- [Homegate](https://github.com/pubky/homegate), from `pubky/homegate`
- [Pubky App](https://github.com/pubky/pubky-app), run as the `pubky-app` Compose service

Third-party infrastructure images such as Postgres, Neo4j, Redis, Redis Insight, and WireMock may still be pulled by Docker.

## Quick Start

Run the setup script from this directory:

```bash
./pubky-docker.sh
```

The script will:

- Check that `git`, Docker, and Docker Compose are available.
- Check that Git can read from GitHub before attempting clones.
- Copy `.env-sample` to `.env` if `.env` does not already exist.
- Ask for a commit, tag, or branch for each service. Press Enter to use the head of the repository's default branch.
- Clone or update the service repositories next to this directory.
- Build local Docker images for Pubky services whose checked-out source commit changed.
- Start the stack with Docker Compose.

The directory containing this project can be named `pubky-docker`, `docker`, or anything else. Repositories are cloned beside that directory.

## Backend Only

If you want to run your own frontend separately, skip the `pubky-app` service:

```bash
./pubky-docker.sh --backend-only
```

This still clones, builds, and runs the backend services: `pubky-core`, `pubky-nexus`, and `homegate`.

## Directory Layout

After running the script, your workspace will look similar to this:

```text
your_working_directory/
├── pubky-docker/
├── pubky-core/
├── pubky-nexus/
├── homegate/
└── pubky-app/
```

## Re-running With Different Refs

Run the script again and enter new refs when prompted:

```bash
./pubky-docker.sh
```

For existing repositories, the script refuses to change refs if there are local changes. Commit, stash, or clean those changes first, then rerun the script.

The script records the last built commit for each Compose service in `.storage/pubky-docker-builds`. On subsequent runs, services at the same commit skip the explicit image build step.

## Manual Compose Commands

The script is the recommended path, but the Compose profiles can also be used directly after repositories have been prepared:

```bash
docker compose --profile backend --profile pubky-app up -d
```

For backend only:

```bash
docker compose --profile backend up -d
```
