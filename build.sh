#PULL_SECRET=~/.pull-secret.json
PULL_SECRET=.pull-secret.json
USER_PASSWD=redhat02
IMAGE_NAME=microshift-4.18-bootc
REGISTRY_URL=quay.io
TAG=$1
REGISTRY_IMG=rhn_engineering_hsirsulw/"${IMAGE_NAME}:${TAG}"
echo "#### Building a new bootc image with MicroShift and application Container images embeeded to it"
podman build --authfile "${PULL_SECRET}" -t "${IMAGE_NAME}" \
    --secret "id=pullsecret,src=${PULL_SECRET}" \
    --build-arg USHIFT_BASE_IMAGE_NAME="${BASE_IMAGE_NAME}" \
    --build-arg USHIFT_BASE_IMAGE_TAG=${TAG} \
    --build-arg USER_PASSWD="${USER_PASSWD}" \
    -f Containerfile.${TAG}

echo "#### pushing bootc image to a registry"
podman push localhost/"${IMAGE_NAME}" "${REGISTRY_URL}/${REGISTRY_IMG}"

echo "#### creating ISO from bootc image"
podman run --authfile ${PULL_SECRET} --rm -it     --privileged     --security-opt label=type:unconfined_t     -v /var/lib/containers/storage:/var/lib/containers/storage     -v ./output:/output     registry.redhat.io/rhel9/bootc-image-builder:latest     --local     --type iso     localhost/${IMAGE_NAME}:${TAG}
