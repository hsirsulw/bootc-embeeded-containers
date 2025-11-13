#!/bin/bash
#
# Script to remove the second NIC from a VM that is connected to the default network
# This will remove external/internet access from the VM
#

set -e

# Configuration
VMNAME="${1:-microshift-4.19-bootc-vm1}"
EXTERNAL_NETWORK="default"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root or with sudo"
    exit 1
fi

# Check if VM exists
if ! virsh dominfo "${VMNAME}" &>/dev/null; then
    print_error "VM '${VMNAME}' does not exist"
    exit 1
fi

# Get current interfaces
print_info "Checking network interfaces for VM '${VMNAME}'..."
IFACE_LIST=$(virsh domiflist "${VMNAME}" 2>/dev/null || true)

# Check if VM has any interface on the external network
if ! echo "${IFACE_LIST}" | grep -q "${EXTERNAL_NETWORK}"; then
    print_warn "VM '${VMNAME}' does not have any interface on network '${EXTERNAL_NETWORK}'"
    print_info "Current interfaces:"
    echo "${IFACE_LIST}"
    exit 0
fi

# Find the MAC address of the interface on the external network
# The domiflist output format is: interface type source model MAC
MAC_ADDRESS=$(echo "${IFACE_LIST}" | grep "${EXTERNAL_NETWORK}" | awk '{print $NF}' | head -1)

if [ -z "${MAC_ADDRESS}" ]; then
    print_error "Could not determine MAC address for interface on network '${EXTERNAL_NETWORK}'"
    print_info "Current interfaces:"
    echo "${IFACE_LIST}"
    exit 1
fi

print_info "Found interface with MAC ${MAC_ADDRESS} on network '${EXTERNAL_NETWORK}'"

# Show current interfaces before removal
print_info "Current network interfaces:"
echo "${IFACE_LIST}"
echo

# Confirm removal
read -p "Do you want to remove the interface on network '${EXTERNAL_NETWORK}'? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Exiting without changes"
    exit 0
fi

# Remove the interface
print_info "Removing interface from VM '${VMNAME}'..."
if virsh detach-interface "${VMNAME}" \
    --type network \
    --mac "${MAC_ADDRESS}" \
    --persistent; then
    print_info "Successfully removed interface from VM '${VMNAME}'"
    echo
    print_info "Updated network interfaces:"
    virsh domiflist "${VMNAME}" 2>/dev/null || true
    echo
    print_info "Rebooting VM to ensure the network interface removal is properly recognized..."
    virsh reboot "${VMNAME}" 2>/dev/null || print_warn "VM may not be running, interface will be removed on next start"
    print_info "VM '${VMNAME}' interface has been removed. The VM will only have access to the isolated network after reboot."
else
    print_error "Failed to remove interface from VM"
    exit 1
fi

