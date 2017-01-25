ALL_ALLOWED_SG_ID="all_allowed_sg_id"
FAKE_SG_ID="fake_sg_id"
NETWORK_NAME="admin_internal_net"
GATEWAY="192.168.0.1"
CIDR="192.168.0.0/24"
IMG="cirros-0.3.4-x86_64-uec"
VM="vm"

function init {
    neutron security-group-create $ALL_ALLOWED_SG_ID;
    neutron security-group-rule-create $ALL_ALLOWED_SG_ID --direction ingress;
    neutron security-group-create $FAKE_SG_ID;
    neutron security-group-rule-create $FAKE_SG_ID --direction ingress --protocol tcp --port-range-max 22 --port-range-min 22;
    neutron net-create $NETWORK_NAME
    neutron subnet-create "$NETWORK_NAME" --name "$NETWORK_NAME-subnet" --gateway $GATEWAY $CIDR
#    neutron port-create $NETWORK_NAME --security-group=$ALL_ALLOWED_SG_ID
}

function boot_vms {
    nova boot --image $IMG --flavor 2 --nic net-name=$NETWORK_NAME --security-group=$ALL_ALLOWED_SG_ID "$VM-all-allowed" --poll
    # vm1
    nova boot --image $IMG --flavor 2 --nic net-name=$NETWORK_NAME --security-group=$FAKE_SG_ID "$VM-fake-1" --poll
    # vm2
    nova boot --image $IMG --flavor 1 --nic net-name=$NETWORK_NAME --security-group=$FAKE_SG_ID "$VM-fake-2" --poll
}

function update_with_huge_cidr {
    all_allowed_address=$(nova list | grep "$VM-all-allowed" | awk '{gsub(".*=", "", $12); print $12}' );
    echo $all_allowed_address;
    all_allowed_port=$(neutron port-list | grep "$all_allowed_address" | awk '{print $2}');
    neutron port-update $all_allowed_port --allowed-address-pairs type=dict list=true ip_address=128.0.0.0/1
    echo "Allowing traffic from FAKE_SG_ID vms to ALL_ALLOWED_VMS"
    neutron security-group-rule-create $FAKE_SG_ID --remote-group-id $ALL_ALLOWED_SG_ID --direction ingress
}

DHCP_NS=$(neutron net-list | grep "$NETWORK_NAME" | awk '{print $2}');
echo "dhcp-namespace is qdhcp-$DHCP_NS";

init
boot_vms
update_with_huge_cidr
