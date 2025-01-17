# 💻 Pubky Deploy

One click setup to run locally an example full Pubky production stack. This orchestration will run:

- [Pkarr relay](https://github.com/pubky/pkarr):
- [Pubky Homeserver](https://github.com/pubky/pubky/tree/main/pubky-homeserver): Instance of pubky decentralized data storage.
- [Pubky Nexus](https://github.com/pubky/pubky-nexus): aggregator and indexer of `/pub/pubky.app` data that creates a powerful social-media-like API
- [Pubky App](https://github.com/pubky/pubky-app): client for the pubky social media app.

## ⚙️ Setup

This repo uses `pubky/pkarr`, `pubky/pubky`, `pubky/pubky-nexus` and `pubky/pubky-app` as Git submodules at the moment as we are not releasing Docker images just yet.

Clone the repo with submodules

```bash
git clone --recurse-submodules -j8 git@github.com:pubky/pubky-docker
cd pubky-docker/development
```

Make a copy of `.env-sample` into `.env` and set your preferences for `mainnet` or `testnet`.

```bash
docker compose up
```
