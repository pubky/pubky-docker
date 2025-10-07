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

## ⚙️ Setup

This repo uses `pubky/pkarr`, `pubky/pubky`, `pubky/pubky-nexus` and `pubky/pubky-app` as directly as the moment as we are not releasing Docker images just yet.

Make a copy of `.env-sample` into `.env` and set your preferences for `mainnet` or `testnet`.

```bash
docker compose up
```

## 📁 Directory Structure Requirement

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
git clone https://github.com/pubky/pubky.git
git clone https://github.com/pubky/pubky-nexus.git
git clone https://github.com/pubky/pubky-app.git
git clone https://github.com/pubky/pubky-core.git
```

Then navigate into `pubky-docker`, configure your `.env`, and run:

```
cd pubky-docker
cp .env-sample .env
# edit .env to choose between mainnet or testnet
docker compose up
```

