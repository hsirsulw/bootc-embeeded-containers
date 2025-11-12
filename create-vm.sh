VMNAME=microshift-4.19-bootc-vm1
NETNAME=bootc-isolated
ISO_FILE="microshift-4.19-bootc-embeeded-v1.iso"
LIBVIRT_IMAGES_DIR="/var/lib/libvirt/images"

# Get the directory where the script is located or use current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ISO="${SCRIPT_DIR}/${ISO_FILE}"
TARGET_ISO="${LIBVIRT_IMAGES_DIR}/${ISO_FILE}"

# Check if source ISO file exists
if [ ! -f "${SOURCE_ISO}" ]; then
    echo "Error: ISO file not found at ${SOURCE_ISO}"
    echo "Please ensure the ISO file exists or update ISO_FILE variable"
    exit 1
fi

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Error: Please run as root or with sudo"
    exit 1
fi

# Ensure libvirt images directory exists
mkdir -p "${LIBVIRT_IMAGES_DIR}"

# Copy ISO to libvirt images directory if it doesn't exist or is different
if [ ! -f "${TARGET_ISO}" ] || [ "${SOURCE_ISO}" -nt "${TARGET_ISO}" ]; then
    echo "Copying ISO to ${TARGET_ISO} (this may take a while for large files)..."
    cp "${SOURCE_ISO}" "${TARGET_ISO}"
    chmod 644 "${TARGET_ISO}"
    echo "ISO copied successfully"
else
    echo "ISO already exists at ${TARGET_ISO}, skipping copy"
fi

# Create the VM using the ISO from libvirt images directory
virt-install --name ${VMNAME} \
--os-variant fedora-coreos-stable \
--memory 8192 \
--vcpus 4 \
--disk size=120 \
--network network=${NETNAME} \
--cdrom "${TARGET_ISO}" \
--wait
