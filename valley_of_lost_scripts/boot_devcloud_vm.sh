#! /bin/sh

# this file is gitignored for paranoid security reasons
OPENRC="mcp-networking-openrc.sh"
FLAVOR="m1.large40"
IMAGE="iv-killme-devuser-tuned"
NETWORK="iv-killme-fwaas"
# our tuned default secgroup already has allow all rules
SECGROUP="default"
KEYNAME="ivasilevskaya"
USER_SCRIPT="fix_resolvconf_install_ansible.sh"
AVAILABILITY_ZONE="nova"
NAME_PREFIX="iv-killme"
FIP_NETWORK="public"

vm_name="$NAME_PREFIX"-"$1"


source "$OPENRC"

# Create the VM from instance snapshot
openstack server create \
    --flavor "$FLAVOR" \
    --image "$IMAGE" \
    --nic net-id="$(openstack network list -f value | grep -w "$NETWORK" | awk '{print $1}')" \
    --security-group "$SECGROUP" \
    --key-name "$KEYNAME" \
    --user-data "$USER_SCRIPT" \
    --availability-zone "$AVAILABILITY_ZONE" \
    --wait \
    "$vm_name"

# Assign floating ip
vm_addr="$(openstack server show "$vm_name" -c addresses | grep addresses| awk '{print $4}'| sed -e 's/.*=//g')"
vm_port="$(openstack port list --network $NETWORK | grep $vm_addr | awk '{print $4}')"
echo "Booted vm's port on internal network is $vm_port"
fip="$(openstack floating ip list | awk '$6 == "None" {print $4}' | head -n 1)"
if ! [[ $fip ]]; then
    echo "No floating ip to use found, creating one.."
    openstack floating ip create "$FIP_NETWORK" -c floating_ip_address | grep floating_ip_address | awk '{print $4}'
fi
echo "Assosiating floating ip $fip with vm $vm_name($vm_port)"
openstack floating ip set --port "$vm_port" "$fip"
