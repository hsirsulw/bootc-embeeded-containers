#!/bin/bash
#
# Script to add a second NIC to a running VM for external access
# The second NIC will be connected to the default network (NAT with external network)
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

# Check if VM is running
VM_STATE=$(virsh domstate "${VMNAME}" 2>/dev/null || echo "shut off")
if [ "${VM_STATE}" != "running" ]; then
    print_warn "VM '${VMNAME}' is not running (current state: ${VM_STATE})"
    print_info "Starting VM..."
    virsh start "${VMNAME}"
    sleep 3
fi

# Check if external network exists, create it if it doesn't
if ! virsh net-info "${EXTERNAL_NETWORK}" &>/dev/null; then
    print_warn "Network '${EXTERNAL_NETWORK}' does not exist"
    print_info "Creating default network..."
    
    # Create default network XML
    DEFAULT_NET_XML="/tmp/default-network.xml"
    cat > "${DEFAULT_NET_XML}" <<EOF
<network>
  <name>${EXTERNAL_NETWORK}</name>
  <uuid>$(uuidgen)</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr0' stp='on' delay='0'/>
  <mac address='52:54:00:00:00:01'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF
    
    # Define and start the network
    virsh net-define "${DEFAULT_NET_XML}"
    virsh net-start "${EXTERNAL_NETWORK}"
    virsh net-autostart "${EXTERNAL_NETWORK}"
    
    # Clean up
    rm -f "${DEFAULT_NET_XML}"
    
    print_info "Network '${EXTERNAL_NETWORK}' created and started"
else
    # Check if network is active
    if ! virsh net-info "${EXTERNAL_NETWORK}" | grep -q "Active:.*yes"; then
        print_info "Starting network '${EXTERNAL_NETWORK}'..."
        virsh net-start "${EXTERNAL_NETWORK}"
    fi
fi

# Get current interfaces
print_info "Checking existing network interfaces for VM '${VMNAME}'..."
CURRENT_IFACES=$(virsh domiflist "${VMNAME}" 2>/dev/null | grep -v "^$" | tail -n +3 | wc -l)

print_info "VM currently has ${CURRENT_IFACES} network interface(s)"

# Check if a second NIC already exists on the external network
if virsh domiflist "${VMNAME}" 2>/dev/null | grep -q "${EXTERNAL_NETWORK}"; then
    print_warn "VM '${VMNAME}' already has an interface on network '${EXTERNAL_NETWORK}'"
    print_info "Current interfaces:"
    virsh domiflist "${VMNAME}" 2>/dev/null
    read -p "Do you want to add another interface anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Exiting without changes"
        exit 0
    fi
fi

# Add the second NIC
print_info "Adding second NIC to VM '${VMNAME}' on network '${EXTERNAL_NETWORK}'..."
if virsh attach-interface "${VMNAME}" \
    --type network \
    --source "${EXTERNAL_NETWORK}" \
    --model virtio \
    --persistent; then
    print_info "Successfully added second NIC to VM '${VMNAME}'"
    print_info "The new interface is connected to network '${EXTERNAL_NETWORK}' (with internet access)"
    echo
    print_info "Updated network interfaces:"
    virsh domiflist "${VMNAME}" 2>/dev/null
    echo
    print_info "Rebooting VM to ensure the new network interface is properly recognized..."
    virsh reboot "${VMNAME}"
    print_info "VM '${VMNAME}' is rebooting. The new interface should be available after reboot."
else
    print_error "Failed to add NIC to VM"
    exit 1
fi

