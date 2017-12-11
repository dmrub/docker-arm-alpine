#!/bin/bash

set -e

export LC_ALL=C
unset CDPATH

THIS_DIR=$( (cd "$(dirname -- "$BASH_SOURCE")" && pwd -P) )

QEMU_VER=v2.9.1-1
QEMU_ARCH=arm
BASE_IMAGE=arm32v6/alpine
BUILD_DIR=$THIS_DIR/build/arm32v6/alpine
BUILD_IMAGE=false
IMAGE_TAG=arm32v6-alpine
NO_CACHE=false

error() {
    echo >&2 "* Error: $@"
}

fatal() {
    error "$@"
    exit 1
}

message() {
    echo "$@"
}

define-download-func() {
    if type -f curl &> /dev/null; then
        download() {
            local url=$1
            local dest=$2

            if [[ ! -f "$dest" ]]; then
                echo "Download $url"
                curl --fail --location --output "$dest" "$url" || \
                    fatal "Could not load $url to $dest"
            else
                echo "File $dest exists, skipping download"
            fi
        }
    elif type -f wget &> /dev/null; then
        download() {
            local url=$1
            local dest=$2

            if [[ ! -f "$dest" ]]; then
                echo "Download $url"
                wget -O "$dest" "$url" || \
                    fatal "Could not load $url to $dest"
            else
                echo "File $dest exists, skipping download"
            fi
        }
    else
        fatal "No download tool detected (checked: curl, wget)"
    fi
}

usage() {
    echo "Generate Dockerfile"
    echo
    echo "$0 [options]"
    echo "options:"
    echo "      --qemu-ver=            QEMU version"
    echo "                             (default ${QEMU_VER})"
    echo "      --base-image=          Use this base image"
    echo "                             (default ${BASE_IMAGE})"
    echo "      --build-dir=           Build directory"
    echo "                             (default ${BUILD_DIR})"
    echo "      --build                Build docker image after generation"
    echo "                             (default ${BUILD_IMAGE})"
    echo "  -t, --tag=                 Image tag (only when building)"
    echo "                             (default: $IMAGE_TAG)"
    echo "      --no-cache             Disable Docker cache (only when building)"
    echo "                             (default: $NO_CACHE)"
    echo "      --help                 Display this help and exit"
}

while [[ $# > 0 ]]; do
    case "$1" in
        --qemu-ver)
            QEMU_VER=($2)
            shift 2
            ;;
        --qemu-ver=*)
            QEMU_VER=(${1#*=})
            shift
            ;;
        --base-image)
            BASE_IMAGE="$2"
            shift 2
            ;;
        --base-image=*)
            BASE_IMAGE="${1#*=}"
            shift
            ;;
        --build)
            BUILD_IMAGE=true
            shift
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --tag=*)
            IMAGE_TAG="${1#*=}"
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --help)
            usage
            exit
            ;;
        --)
            shift
            break
            ;;
        -*)
            fatal "Unknown option $1"
            ;;
        *)
            break
            ;;
    esac
done

echo "QEMU_VER:          ${QEMU_VER}"
echo "BASE_IMAGE:        ${BASE_IMAGE}"
echo "BUILD_DIR:         ${BUILD_DIR}"
echo "IMAGE_TAG:         ${IMAGE_TAG}"

if [[ "$NO_CACHE" == "true" ]]; then
    echo "NO_CACHE:          true"
else
    echo "NO_CACHE:          false"
fi

define-download-func

mkdir -p "$BUILD_DIR"

# install qemu-user-static
if [[ ! -f "$BUILD_DIR/x86_64_qemu-${QEMU_ARCH}-static.tar.gz" ]]; then
    download \
        "https://github.com/multiarch/qemu-user-static/releases/download/${QEMU_VER}/x86_64_qemu-${QEMU_ARCH}-static.tar.gz" \
        "$BUILD_DIR/x86_64_qemu-${QEMU_ARCH}-static.tar.gz"
fi

cat > "$BUILD_DIR/Dockerfile" <<EOF
FROM $BASE_IMAGE

# Add qemu-user-static binary for amd64 builders
ADD x86_64_qemu-${QEMU_ARCH}-static.tar.gz /usr/bin
EOF

if [[ "$BUILD_IMAGE" == "true" ]]; then
    DOCKER_OPTS=()
    if [[ "$NO_CACHE" == "true" ]]; then
        DOCKER_OPTS+=(--no-cache)
    fi
    set -xe
    docker build "${DOCKER_OPTS[@]}" -t "${IMAGE_TAG}" "${BUILD_DIR}"

    # Register binfmt
    docker run --rm --privileged multiarch/qemu-user-static:register --reset

    docker run --rm "${IMAGE_TAG}" /bin/sh -ec "echo Hello from Alpine !; set -x; uname -a; cat /etc/alpine-release"
    echo "Built image $IMAGE_TAG"
fi
