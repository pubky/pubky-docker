# Pubky Docker

> [!WARNING]
> This project is intended for local development and experimentation only. It is not production hosting infrastructure.
> Do not use it to run public, production, or mission-critical Pubky services; production deployments require infrastructure that is hardened, monitored, maintained, and operated for that purpose.

One-click setup to run a local Pubky Social stack. This orchestration can run:

- [Pubky Homeserver](https://github.com/pubky/pubky-core/tree/main/pubky-homeserver), from `pubky/pubky-core`
- [Pubky Nexus](https://github.com/pubky/pubky-nexus), from `pubky/pubky-nexus`
- [Homegate](https://github.com/pubky/homegate), from `pubky/homegate`
- [Pubky App](https://github.com/pubky/pubky-app), as the `pubky-app` Compose service

Third-party infrastructure images (Postgres, Neo4j, Redis, Redis Insight, WireMock) are pulled from their public registries.

## Warning

Running the full stack is overkill if your goal is only to develop an application using Pubky. For application development, use the official client libraries instead:

- JavaScript: https://www.npmjs.com/package/@synonymdev/pubky
- Rust: https://crates.io/crates/pubky

Only run this full orchestration if you are experimenting with the complete stack, especially the Nexus indexer and the social frontend.

## Using Public Docker Images (Recommended)

All Pubky service images are published on the public [Synonymsoft registry](https://hub.docker.com/u/synonymsoft). By default, Compose uses the `latest` tag.

Image tags and registry can be overridden in `.env`:

```text
REGISTRY          # default: synonymsoft
HOMESERVER_TAG    # default: latest
PUBKY_NEXUS_TAG   # default: latest
PUBKY_APP_TAG     # default: latest
HOMEGATE_TAG      # default: latest
```

Copy `.env-sample` to `.env` for default `testnet` config:

```bash
cp .env-sample .env
```

Start the full stack:

```bash
docker compose up -d --no-build
```

Backend only:

```bash
docker compose --profile backend up -d --no-build
```

This path does not clone or build service repositories. You only need the compose files from this project and a configured `.env`.

## Local Setup From Source

### Manual Compose

If you have already cloned the service repositories and checked out refs yourself, build the local images first:

Copy `.env-sample` to `.env` for default `testnet` config:

```bash
cp .env-sample .env
```

```bash
docker compose build
```

Then start the full stack:

```bash
docker compose up -d
```

Backend only (If you want to run your own frontend separately):

```bash
docker compose --profile backend up -d
```

### CLI

If you need specific commits, are working on service code, or cannot rely on the registry, use `pubky-docker-cli.sh`. It clones the service repositories, checks out the refs you choose, builds Pubky images from source, and starts the stack.

Run the script from this directory:

```bash
./pubky-docker-cli.sh
```

The script will:

- Check that `git`, Docker, and Docker Compose are available.
- Check that Git can read from GitHub before attempting clones.
- Copy `.env-sample` to `.env` if `.env` does not already exist.
- If `.build-state` has a complete record for the selected services, list those commits and offer to start the stack immediately or proceed to ref selection.
- Ask for a commit, tag, or branch for each service. Press Enter to use the head of the repository's default branch.
- Clone or update the service repositories next to this directory.
- Build local Docker images only for services whose checked-out commit changed.
- Start the stack with Docker Compose.

The directory containing this project can be named `pubky-docker`, `docker`, or anything else. Repositories are cloned beside that directory.

Backend only:

```bash
./pubky-docker-cli.sh --backend-only
```

### Directory Layout

After running the script, your workspace will look similar to this:

```text
your_working_directory/
├── pubky-docker/
├── pubky-core/
├── pubky-nexus/
├── homegate/
└── pubky-app/
```

### Re-running

Run the script again to pick new refs:

```bash
./pubky-docker-cli.sh
```

For existing repositories, the script refuses to change refs if there are local changes. Commit, stash, or clean those changes first, then rerun.

The script records the last built commit per Compose service in `.build-state`. On later runs, unchanged services skip the image build step. If `.build-state` is complete for your selected profile set, you can start the stack without going through ref selection again.

