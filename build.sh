#!/bin/bash
set -e

IMAGE_NAME=microshift-4.18-bootc-embeeded
REGISTRY_URL=quay.io
TAG=$1

if [ -z "$TAG" ]; then
    echo "Error: a tag must be provided."
    echo "Usage: $0 <tag>"
    exit 1
fi

#REGISTRY_IMG="rhn_support_arolivei/${IMAGE_NAME}"
BASE_IMAGE_NAME=microshift-4.18-bootc:${TAG}

echo "#### Building a new bootc image with MicroShift and application Container images embeeded to it"
sudo podman build -t "${IMAGE_NAME}:${TAG}" \
    --volume /etc/rhsm:/etc/rhsm:ro,z \
    --volume /etc/pki/entitlement:/etc/pki/entitlement:ro,z \
    --volume /etc/yum.repos.d:/etc/yum.repos.d:ro,z \
    --volume /etc/containers/registries.conf.d/99-mirrors.conf:/etc/containers/registries.conf.d/99-mirrors.conf:ro,z \
    --build-arg USHIFT_BASE_IMAGE_NAME="${BASE_IMAGE_NAME}" \
    --build-arg USHIFT_BASE_IMAGE_TAG=${TAG} \
    -f Containerfile.${TAG}

#echo "#### pushing bootc image to a registry"
#podman push "localhost/${IMAGE_NAME}:${TAG}" "${REGISTRY_URL}/${REGISTRY_IMG}:${TAG}"

sudo mkdir -p /var/tmp/bootc-images
echo "#### creating ISO from bootc image"
sudo podman run --rm -it --privileged --security-opt label=type:unconfined_t \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    -v /var/tmp/bootc-images:/output \
    --volume /etc/rhsm:/etc/rhsm:ro \
    --volume /etc/pki/entitlement:/etc/pki/entitlement:ro \
    --volume /etc/yum.repos.d:/etc/yum.repos.d:ro \
    registry.redhat.io/rhel9/bootc-image-builder:latest \
    --local --type iso localhost/${IMAGE_NAME}:${TAG}