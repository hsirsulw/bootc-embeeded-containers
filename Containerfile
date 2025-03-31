FROM registry.redhat.io/rhel9/rhel-bootc:9.4

ARG USHIFT_VER=4.18
RUN dnf config-manager \
        --set-enabled rhocp-${USHIFT_VER}-for-rhel-9-$(uname -m)-rpms \
        --set-enabled fast-datapath-for-rhel-9-$(uname -m)-rpms
RUN dnf install -y firewalld microshift* && \
    systemctl enable microshift && \
#    dnf update -y && \
    dnf clean all

# Create a default 'redhat' user with the specified password.
# Add it to the 'wheel' group to allow for running sudo commands.
ARG USER_PASSWD
RUN if [ -z "${USER_PASSWD}" ] ; then \
        echo USER_PASSWD is a mandatory build argument && exit 1 ; \
    fi
RUN useradd -m -d /var/home/redhat -G wheel redhat && \
    echo "redhat:${USER_PASSWD}" | chpasswd

# Mandatory firewall configuration
RUN firewall-offline-cmd --zone=public --add-port=22/tcp && \
    firewall-offline-cmd --zone=trusted --add-source=10.42.0.0/16 && \
    firewall-offline-cmd --zone=trusted --add-source=169.254.169.1

# Create a systemd unit to recursively make the root filesystem subtree
# shared as required by OVN images
RUN cat > /etc/systemd/system/microshift-make-rshared.service <<'EOF'
[Unit]
Description=Make root filesystem shared
Before=microshift.service
ConditionVirtualization=container
[Service]
Type=oneshot
ExecStart=/usr/bin/mount --make-rshared /
[Install]
WantedBy=multi-user.target
EOF
RUN systemctl enable microshift-make-rshared.service


ENV IMAGE_STORAGE_DIR=/usr/lib/containers/storage
ENV IMAGE_LIST_FILE=${IMAGE_STORAGE_DIR}/image-list.txt

# Pull the container images into /usr/lib/containers/storage:
# - Each image goes into a separate sub-directory
# - Sub-directories are named after the image reference string SHA
# - An image list file maps image references to their name SHA
# hadolint ignore=DL4006
RUN --mount=type=secret,id=pullsecret,dst=/run/secrets/pull-secret.json \
    images="$(jq -r ".images[]" /usr/share/microshift/release/release-"$(uname -m)".json)" ; \
    mkdir -p "${IMAGE_STORAGE_DIR}" ; \
    skopeo copy --all --preserve-digests "docker://docker.io/library/wordpress:6.2.1-apache" "dir:$IMAGE_STORAGE_DIR/${sha}" ; \
    for img in ${images} ; do \
        sha="$(echo "${img}" | sha256sum | awk '{print $1}')" ; \
        skopeo copy --all --preserve-digests \
            --authfile /run/secrets/pull-secret.json \
            "docker://${img}" "dir:$IMAGE_STORAGE_DIR/${sha}" ; \
        echo "${img},${sha}" >> "${IMAGE_LIST_FILE}" ; \
    done
# Install a systemd drop-in unit to address the problem with image upgrades
# overwriting the container images in additional store. The workaround is to
# copy the images from the pre-loaded to the main container storage.
# In this case, it is not necessary to update /etc/containers/storage.conf with
# the additional store path.
# See https://issues.redhat.com/browse/RHEL-75827
RUN mkdir -p /etc/systemd/system/microshift.service.d
# hadolint ignore=DL3059
RUN cat > /etc/systemd/system/microshift.service.d/microshift-copy-images.conf <<EOF
[Service]
ExecStartPre=/bin/bash -eux -o pipefail -c '\
    while IFS="," read -r img sha ; do \
        skopeo copy --preserve-digests \
            "dir:${IMAGE_STORAGE_DIR}/\${sha}" \
            "containers-storage:\${img}" ; \
    done < "${IMAGE_LIST_FILE}" \
'
EOF
