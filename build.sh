#!/bin/bash
set -e

REGISTRY_URL=quay.io
TAG=$1

if [ -z "$TAG" ]; then
    echo "Error: a tag must be provided."
    echo "Usage: $0 <tag>"
    exit 1
fi

# Set IMAGE_NAME and BASE_IMAGE_NAME based on TAG (case-insensitive)
TAG_LOWER=$(echo "$TAG" | tr '[:upper:]' '[:lower:]')
case "$TAG_LOWER" in
    v1)
        IMAGE_NAME=microshift-4.19-bootc-embeeded
        BASE_IMAGE_NAME=microshift-4.19-bootc:${TAG}
        ;;
    v2)
        IMAGE_NAME=microshift-4.20-bootc-embeeded
        BASE_IMAGE_NAME=microshift-4.20-bootc:${TAG}
        ;;
    *)
        echo "Error: TAG must be either v1/V1 or v2/V2"
        exit 1
        ;;
esac

#REGISTRY_IMG="rhn_support_arolivei/${IMAGE_NAME}"

# For v2, configure dnf repositories
if [ "$TAG_LOWER" = "v2" ]; then
    echo "#### Configuring dnf repositories for v2"
    sudo dnf config-manager \
        --set-enabled rhocp-4.20-for-rhel-9-$(uname -m)-rpms \
        --set-enabled fast-datapath-for-rhel-9-$(uname -m)-rpms
    sudo dnf config-manager \
        --set-disabled rhocp-4.18-for-rhel-9-$(uname -m)-rpms \
        --set-disabled rhocp-4.19-for-rhel-9-$(uname -m)-rpms
    cp /etc/yum.repos.d/redhat.repo /home/lab-user/bootc-embeeded-containers
fi

echo "#### Building a new bootc image with MicroShift and application Container images embeeded to it"
sudo podman build -t "${IMAGE_NAME}:${TAG}" \
    --volume /etc/rhsm:/etc/rhsm:ro,z \
    --volume /etc/pki/entitlement:/etc/pki/entitlement:ro,z \
    --volume /etc/yum.repos.d:/etc/yum.repos.d:ro,z \
    --volume /etc/containers/registries.conf.d/99-mirrors.conf:/etc/containers/registries.conf.d/99-mirrors.conf:ro,z \
    --volume /etc/containers/policy.json:/etc/containers/policy.json:ro,z \
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
    registry.redhat.io/rhel9/bootc-image-builder:latest \
    --progress=verbose --local --type iso localhost/${IMAGE_NAME}:${TAG}

cp -v /var/tmp/bootc-images/bootiso/install.iso microshift-4.19-bootc-embeeded-v1.iso