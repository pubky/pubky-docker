# 💻 Pubky Docker

One click setup to run locally an example full Pubky Social (App) stack. This orchestration will run:

- [Pkarr relay](https://github.com/pubky/pkarr):
- [Pubky Homeserver](https://github.com/pubky/pubky/tree/main/pubky-homeserver): Instance of pubky decentralized data storage.
- [Pubky Nexus](https://github.com/pubky/pubky-nexus): aggregator and indexer of `/pub/pubky.app` data that creates a powerful social-media-like API
- [Pubky App](https://github.com/pubky/pubky-app): client for the pubky social media app.

## ⚠️ Warning

Running the full stack is overkill if your goal is only to develop an application using Pubky.

For application development, use the official client libraries instead:

- JavaScript: https://www.npmjs.com/package/@synonymdev/pubky
- Rust: https://crates.io/crates/pubky

Only run this full orchestration if you're specifically experimenting with the complete stack with interest on the Nexus indexer and the social frontend client.

## Using public docker images

All images are stored in public [registry](https://hub.docker.com/u/synonymsoft) and by default the `latest` tag is used.

The image tag and registry are envinroment variables, so if needed they could be changed

```
REGISTRY - registry by default synonymsoft
PUBKY_APP_TAG - tag for pubky-app/client by default latest
PUBKY_NEXUS_TAG - tag for pubky-nexus by default latest
HOMESERVER_TAG - tag for homeserver by default latest
PKARR_TAG - tag for pkarr by default latest
```

Make a copy of `.env-sample` into `.env` and set your preferences for `mainnet` or `testnet`.

Run:
```
docker compose up -d
```

## Building from scratch

### ⚙️ Setup

This repo uses `pubky/pkarr`, `pubky/pubky`, `pubky/pubky-nexus` and `pubky/pubky-app` as directly as the moment.

Make a copy of `.env-sample` into `.env` and set your preferences for `mainnet` or `testnet`.

```bash
docker compose up
```

### 📁 Directory Structure Requirement

Before running `docker compose up`, ensure the following four repositories are cloned **at the same directory level** as `pubky-docker`. This is necessary because the Docker setup references them via relative paths.

Your directory should look like this:

```
your_working_directory/
├── pubky-docker/ # this project!
├── pkarr/
├── pubky/
├── pubky-nexus/
├── pubky-app/
```

Clone each required repository:

```
git clone https://github.com/pubky/pubky-docker.git # this repository
git clone https://github.com/pubky/pkarr.git
git clone https://github.com/pubky/pubky-core.git
git clone https://github.com/pubky/pubky-nexus.git
git clone https://github.com/pubky/pubky-app.git
```

Then navigate into `pubky-docker`, configure your `.env`, and run:

```
cd pubky-docker
cp .env-sample .env
# edit .env to choose between mainnet or testnet
docker compose up
```

