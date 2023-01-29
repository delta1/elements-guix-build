#!/bin/bash -x

## to create the buildimage
## git clone https://github.com/fanquake/core-review.git
## cd core-review/guix/
## DOCKER_BUILDKIT=1 docker build --pull --no-cache -t alpine-guix - < Dockerfile

export ELEMENTS_SRC="$PWD/elements/"

set -e

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

echo "host: $HOST"


cat >tmpelementsbuild.sh <<__EOF__
#!/bin/bash

set -ex
chown -R root:root /elements
cd /elements
# git checkout $tag
export SOURCES_PATH=/sources
export BASE_CACHE=/base_cache

export HOSTS="$HOST"
echo $HOSTS

./contrib/guix/guix-clean

if [ ! -d /elements/depends/SDKs/Xcode-12.1-12A7403-extracted-SDK-with-libcxx-headers ];then
    mkdir -p /elements/depends/SDKs/
    pushd /elements/depends/SDKs/
    tar -xf /sources/Xcode-12.1-12A7403-extracted-SDK-with-libcxx-headers.tar.gz
    popd
fi

export FORCE_DIRTY_WORKTREE=true
./contrib/guix/guix-build
ls -alht $builddir
ls -alht $builddir/output/
find ${builddir}/output/ -type f -print0 | env LC_ALL=C sort -z | xargs -r0 sha256sum
FILES=$(find "$builddir"/output/ -type f -print0)
echo \$FILES
echo \$FILES | env LC_ALL=C sort -z | xargs -r0 sha256sum > $builddir/output/sha256sum.txt
__EOF__

chmod 700 tmpelementsbuild.sh
docker cp tmpelementsbuild.sh elementsbuild:/root/elementsbuild.sh
docker cp sources/. elementsbuild:/sources/
docker exec -i elementsbuild /root/elementsbuild.sh
mkdir -p output/
docker cp elementsbuild:/elements/"$builddir"/output/ output/
