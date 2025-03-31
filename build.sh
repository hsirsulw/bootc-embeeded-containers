PULL_SECRET=~/.pull-secret.json
USER_PASSWD=redhat02
IMAGE_NAME=microshift-4.18-bootc

podman build --authfile "${PULL_SECRET}" -t "${IMAGE_NAME}" \
    --secret "id=pullsecret,src=${PULL_SECRET}" \
    --build-arg USHIFT_BASE_IMAGE_NAME="${BASE_IMAGE_NAME}" \
    --build-arg USHIFT_BASE_IMAGE_TAG=v1 \
    --build-arg USER_PASSWD="${USER_PASSWD}" \
    -f Containerfile
#podman build --authfile "${PULL_SECRET}" -t "${IMAGE_NAME}" \
#    --build-arg USER_PASSWD="${USER_PASSWD}" \
#    -f Containerfile
REGISTRY_URL=quay.io
REGISTRY_IMG=rhn_support_arolivei/"${IMAGE_NAME}:v1"
podman push localhost/"${IMAGE_NAME}" "${REGISTRY_URL}/${REGISTRY_IMG}"

echo "#### creating ISO"
podman run --authfile ${PULL_SECRET} --rm -it     --privileged     --security-opt label=type:unconfined_t     -v /var/lib/containers/storage:/var/lib/containers/storage     -v ./output:/output     registry.redhat.io/rhel9/bootc-image-builder:latest     --local     --type iso     localhost/${IMAGE_NAME}:v1
