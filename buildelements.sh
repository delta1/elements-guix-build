#!/bin/bash -x

## to create the buildimage
## git clone https://github.com/fanquake/core-review.git
## cd core-review/guix/
## DOCKER_BUILDKIT=1 docker build --pull --no-cache -t alpine-guix - < Dockerfile

export ELEMENTS_SRC="$PWD/elements/"

set -e

# Host-side cache directories, bind-mounted into the build container so their
# contents persist across CI runs (via actions/cache in the workflow) instead
# of being downloaded/rebuilt from scratch every time.
#
#   SOURCES_DIR      -> /sources     depends download cache (SOURCES_PATH) +
#                                     misc pre-fetched sources (e.g. macOS SDK)
#   BASE_CACHE_DIR   -> /base_cache  depends build cache (BASE_CACHE), per-host
#
# The guix store/database (/gnu/store, /var/guix) is only cached for a single
# host (selected by the workflow via CACHE_GUIX_STORE=true) to stay within
# GitHub Actions' 10GiB per-repo cache limit, since the full guix substitute
# closure would otherwise be duplicated per matrix host.
SOURCES_DIR="${SOURCES_DIR:-$PWD/cache/sources}"
BASE_CACHE_DIR="${BASE_CACHE_DIR:-$PWD/cache/base_cache-$HOST}"
mkdir -p "$SOURCES_DIR" "$BASE_CACHE_DIR"

GUIX_STORE_MOUNTS=()
if [ "${CACHE_GUIX_STORE:-false}" = "true" ]; then
    GUIX_STORE_DIR="${GUIX_STORE_DIR:-$PWD/cache/gnu-store}"
    GUIX_VAR_DIR="${GUIX_VAR_DIR:-$PWD/cache/var-guix}"
    mkdir -p "$GUIX_STORE_DIR" "$GUIX_VAR_DIR"

    # The alpine-guix image ships with a pre-populated /gnu/store and /var/guix
    # (the extracted guix binary install, including the guix-daemon database and
    # the ~root/.config/guix/current profile symlink target). If we bind-mount
    # empty (cache-miss) host directories straight over those paths, that baked-in
    # install is hidden and the `guix` command breaks entirely. So on a cache miss,
    # seed the host cache dirs from the image first, then bind-mount over them as
    # usual; a successful build will grow these dirs with the real substitute
    # closure for actions/cache to persist.
    #
    # NB: this must be done with `docker run ... cp -a` (a real copy performed by
    # root *inside* the container), not `docker cp` (container -> host). `docker
    # cp` extracts client-side as the unprivileged host runner user, and guix
    # store entries are intentionally read-only directories/files (e.g. dr-xr-xr-x),
    # so the client can't create files underneath them once extracted -> EACCES.
    # Copying as root inside the container has no such problem.
    if [ -z "$(ls -A "$GUIX_VAR_DIR" 2>/dev/null)" ] || [ -z "$(ls -A "$GUIX_STORE_DIR" 2>/dev/null)" ]; then
        echo "guix store cache is empty, seeding from ghcr.io/delta1/alpine-guix image..."
        docker run --rm \
            -v "$GUIX_STORE_DIR":/host-store \
            -v "$GUIX_VAR_DIR":/host-var \
            ghcr.io/delta1/alpine-guix \
            sh -c 'cp -a /gnu/store/. /host-store/ && cp -a /var/guix/. /host-var/'
    fi

    GUIX_STORE_MOUNTS=(-v "$GUIX_STORE_DIR":/gnu/store -v "$GUIX_VAR_DIR":/var/guix)
fi

running=$(docker container list | grep elementsbuild || :)

if [ -z "$running" ];then
    docker container stop elementsbuild || :
    docker container rm -f elementsbuild || :
    docker run -dt --name elementsbuild --privileged \
        -v "$ELEMENTS_SRC":/elements/ \
        -v "$SOURCES_DIR":/sources/ \
        -v "$BASE_CACHE_DIR":/base_cache/ \
        "${GUIX_STORE_MOUNTS[@]}" \
        ghcr.io/delta1/alpine-guix
fi

#if you build a hash instead of a tag, remember to use only the first 12 chars
tag=$BUILD_TAG
echo "tag: ${tag}"

tagbuild=${tag#elements-}
echo "tagbuild: ${tagbuild}"

builddir="guix-build-${tagbuild#v}"
echo "builddir: ${builddir}"

echo "host: $HOST"
NAME=${HOST//-/_}
echo "name: $NAME"

echo "macos sdk: $MACOS_SDK"


cat >tmpelementsbuild.sh <<__EOF__
#!/bin/bash

set -ex
chown -R root:root /elements
cd /elements
# # git checkout $tag
export SOURCES_PATH=/sources
export BASE_CACHE=/base_cache

export HOSTS="$HOST"
echo $HOST
echo $NAME

sed -i 's|https://codeberg.org/guix.git|https://codeberg.org/guix/guix.git|g' contrib/guix/guix-build contrib/guix/guix-codesign

./contrib/guix/guix-clean

if [[ $HOST == *"apple"* ]];then
    if [ ! -d /elements/depends/SDKs/$MACOS_SDK ];then
        mkdir -p /elements/depends/SDKs/
        pushd /elements/depends/SDKs/
        # NOTE: the SDK tarball is already made available at /sources/$MACOS_SDK.tar.gz
        # (copied in from the host's ./sources dir below), so it does not need to be
        # re-downloaded here.
        tar -xf /sources/$MACOS_SDK.tar.gz
        popd
    fi
fi

export FORCE_DIRTY_WORKTREE=true
time ./contrib/guix/guix-build
pwd
ls -alht
echo $builddir
ls -alht $builddir
ls -alht $builddir/output/
find $builddir/output/ -type f -print0 | env LC_ALL=C sort -z | xargs -r0 sha256sum | tee $NAME.txt
mv $NAME.txt $builddir/output/$NAME.txt
__EOF__

chmod 700 tmpelementsbuild.sh
docker cp tmpelementsbuild.sh elementsbuild:/root/elementsbuild.sh
docker cp sources/. elementsbuild:/sources/
docker exec -i elementsbuild /root/elementsbuild.sh
mkdir -p output/
docker cp elementsbuild:/elements/"$builddir"/output/ output/
