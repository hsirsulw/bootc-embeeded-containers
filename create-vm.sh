VMNAME=microshift-4.19-bootc-vm1
NETNAME=bootc-isolated
ISO_FILE="microshift-4.19-bootc-embeeded-v1.iso"

# Get the directory where the script is located or use current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_PATH="${SCRIPT_DIR}/${ISO_FILE}"

# Check if ISO file exists
if [ ! -f "${ISO_PATH}" ]; then
    echo "Error: ISO file not found at ${ISO_PATH}"
    echo "Please ensure the ISO file exists or update ISO_FILE variable"
    exit 1
fi

sudo virt-install --name ${VMNAME} \
--os-variant fedora-coreos-stable \
--memory 8192 \
--vcpus 4 \
--disk size=120 \
--network network=${NETNAME} \
--cdrom "${ISO_PATH}" \
--wait
