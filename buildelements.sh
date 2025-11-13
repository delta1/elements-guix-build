#!/bin/bash -x

## to create the buildimage
## git clone https://github.com/fanquake/core-review.git
## cd core-review/guix/
## DOCKER_BUILDKIT=1 docker build --pull --no-cache -t alpine-guix - < Dockerfile

export ELEMENTS_SRC="/home/byron/code/elements/"
export BUILD_TAG="elements-23.3.1rc3"
#export HOST="x86_64-linux-gnu"

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

#echo "host: $HOST"
#NAME=${HOST//-/_}
#echo "name: $NAME"

MACOS_SDK="Xcode-12.2-12B45b-extracted-SDK-with-libcxx-headers"
echo "macos sdk: $MACOS_SDK"

cat >tmpelementsbuild.sh <<__EOF__
#!/bin/bash

set -ex
chown -R root:root /elements
cd /elements
# # git checkout $tag
export SOURCES_PATH=/sources
export BASE_CACHE=/base_cache

#export HOSTS="$HOST"
#echo $HOST
#echo $NAME

./contrib/guix/guix-clean

#if [[ $HOST == *"apple"* ]];then
    if [ ! -d /elements/depends/SDKs/$MACOS_SDK ];then
        mkdir -p /elements/depends/SDKs/
        pushd /elements/depends/SDKs/
        wget https://bitcoincore.org/depends-sources/sdks/$MACOS_SDK.tar.gz
        tar -xf /sources/$MACOS_SDK.tar.gz
        popd
    fi
#fi

export FORCE_DIRTY_WORKTREE=true
time ./contrib/guix/guix-build
#pwd
#ls -alht
#echo $builddir
#ls -alht $builddir
#ls -alht $builddir/output/
#find $builddir/output/ -type f -print0 | env LC_ALL=C sort -z | xargs -r0 sha256sum | tee $NAME.txt
#mv $NAME.txt $builddir/output/$NAME.txt
__EOF__

chmod 700 tmpelementsbuild.sh
docker cp tmpelementsbuild.sh elementsbuild:/root/elementsbuild.sh
docker cp sources/. elementsbuild:/sources/
docker exec -i elementsbuild /root/elementsbuild.sh
mkdir -p "$builddir"/
docker cp elementsbuild:/elements/"$builddir"/output/ "$builddir"/
find $builddir/output/ -type f -print0 | env LC_ALL=C sort -z | xargs -r0 sha256sum
