[![Guix Build](https://github.com/delta1/elements-guix-build/actions/workflows/guix.yml/badge.svg)](https://github.com/delta1/elements-guix-build/actions/workflows/guix.yml)

# Elements Guix Builds

This repo uses Github Actions to run create reproducible Guix builds for an [Elements](/ElementsProject/elements) release.

## Prerequisites

- [alpine-guix](https://github.com/fanquake/core-review/blob/master/guix/README.md#create-the-alpine-guix-image) docker image. This repo is currently hardcoded to use the image pushed to `ghcr.io/delta1/alpine-guix`
- a "Repository secret" in [settings/secrets/actions](settings/secrets/actions) named `READ_TOKEN` with the value of a [github token](/settings/tokens) with the permission to `read:packages` for the alpine-guix docker image

## Usage

1. Go to Actions > Guix Build
2. Click "Run Workflow" button
3. Complete the required inputs
4. ???
5. Profit!

## Caching

To reduce download/build time across runs, the workflow caches (via `actions/cache`):

- **depends sources** (`SOURCES_PATH`), keyed on `depends/packages/*.mk`, shared across all hosts
- **depends build cache** (`BASE_CACHE`), keyed per-host on `depends/packages/*.mk`
- **the guix store/database** (`/gnu/store`, `/var/guix`), but only for the `x86_64-linux-gnu`
  leg, since this closure is identical across hosts and caching it per-host would exceed
  GitHub's 10GiB per-repo cache limit

These are bind-mounted into the build container by `buildelements.sh` (see `SOURCES_DIR`,
`BASE_CACHE_DIR`, `GUIX_STORE_DIR`, `GUIX_VAR_DIR`, `CACHE_GUIX_STORE` env vars).

<img src="https://github.com/delta1/elements-guix-build/assets/351403/26bef92d-3991-4f5c-b5bf-9e47fb7f61d8" style="height:250px">
