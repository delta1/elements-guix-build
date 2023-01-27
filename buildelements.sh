#!/bin/bash -x

## to create the buildimage
## git clone https://github.com/fanquake/core-review.git
## cd core-review/guix/
## DOCKER_BUILDKIT=1 docker build --pull --no-cache -t alpine-guix - < Dockerfile

export ELEMENTS_SRC="$PWD/elements/"
# export GUIX_DIR="$PWD/elementsguix/"

set -e
# mkdir -p "$GUIX_DIR"

running=$(docker container list | grep elementsbuild || :)

if [ -z "$running" ];then
    docker container stop elementsbuild || :
    docker container rm -f elementsbuild || :
    docker run -dt --name elementsbuild --privileged -v "$ELEMENTS_SRC":/elements/ ghcr.io/delta1/alpine-guix
fi

#if you build a hash instead of a tag, remember to use only the first 12 chars
tag=$BUILD_TAG
echo "tag: ${tag}"

tagbuild=${tag#elements-}
echo "tagbuild: ${tagbuild}"

builddir="guix-build-${tagbuild#v}"
echo "builddir: ${builddir}"


# sudo mkdir -p "$GUIX_DIR"
# sudo rsync -aq --delete "${ELEMENTS_SRC}" "$GUIX_DIR"
# sudo chown -R root:root "$ELEMENTS_SRC"

cat >tmpelementsbuild.sh <<__EOF__
#!/bin/bash

set -ex
chown -R root:root /elements
cd /elements
# git checkout $tag
export SOURCES_PATH=/sources
export BASE_CACHE=/base_cache

HOSTS=""

# if HOSTS is empty it builds all of these targets
# HOSTS+=" aarch64-linux-gnu"
# HOSTS+=" arm-linux-gnueabihf"
# HOSTS+=" powerpc64le-linux-gnu"
# HOSTS+=" powerpc64-linux-gnu"
# HOSTS+=" riscv64-linux-gnu"
# HOSTS+=" x86_64-apple-darwin18"
# HOSTS+=" x86_64-linux-gnu"
# HOSTS+=" x86_64-w64-mingw32"

export HOSTS

./contrib/guix/guix-clean

if [ ! -d /elements/depends/SDKs/Xcode-12.1-12A7403-extracted-SDK-with-libcxx-headers ];then
    mkdir -p /elements/depends/SDKs/
    pushd /elements/depends/SDKs/
    tar -xf /sources/Xcode-12.1-12A7403-extracted-SDK-with-libcxx-headers.tar.gz
    popd
fi

export FORCE_DIRTY_WORKTREE=true
./contrib/guix/guix-build
find ${builddir}/output/ -type f -print0 | env LC_ALL=C sort -z | xargs -r0 sha256sum
__EOF__

chmod 700 tmpelementsbuild.sh
docker cp tmpelementsbuild.sh elementsbuild:/root/elementsbuild.sh
docker cp sources/. elementsbuild:/sources/
docker exec -i elementsbuild /root/elementsbuild.sh
mkdir -p out/
docker cp elementsbuild:/elements/"$builddir"/output/ out/
