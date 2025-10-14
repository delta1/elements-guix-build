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

<img src="https://github.com/delta1/elements-guix-build/assets/351403/26bef92d-3991-4f5c-b5bf-9e47fb7f61d8" style="height:250px">
