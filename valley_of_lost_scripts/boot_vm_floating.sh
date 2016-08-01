#!/bin/sh
source openrc

EXT="admin_floating_net"
INT="mydemo"
SECGROUP="mysecgroup"
ROUTER="demo-router"
EXT_POOL="start=172.18.171.86,end=172.18.171.90"
EXT_GATEWAY="172.18.171.1"
EXT_CIDR="172.18.171.0/25"
INT_GATEWAY="20.10.0.1"
INT_CIDR="20.10.0.0/24"
VM="vm-$RANDOM"
IMG="TestVM"


function create_ext_net {
    neutron net-create "$EXT" --router:external True --provider:network_type local

    neutron subnet-create "$EXT" --name "$EXT-subnet" --allocation-pool $EXT_POOL --disable-dhcp --gateway $EXT_GATEWAY $EXT_CIDR
}

function create_int_net {
    exists=$(neutron net-list | grep "$INT" | awk '{print $1}')
    if [[ $exists ]] ; then
        echo "Subnet $INT-subnet exists, not recreating it"
        return
    fi
    neutron net-create "$INT"
    neutron subnet-create "$INT" --name "$INT-subnet" --gateway $INT_GATEWAY $INT_CIDR
}

function create_router {
    exists=$(neutron router-list | grep "$ROUTER" | awk '{print $1}')
    if [[ $exists ]] ; then
        echo "Router $ROUTER exists, not recreating it"
        return
    fi
    neutron router-create $ROUTER
    neutron router-interface-add $ROUTER "$INT-subnet"
    neutron router-gateway-set $ROUTER "$EXT"
}

function create_secgroup_nova {
    exists=$(nova secgroup-list | grep $SECGROUP)
    if [[ $exists ]] ; then
        echo "Secutity group $SECGROUP exists, not recreating it"
        return
    fi
    nova secgroup-create $SECGROUP $SECGROUP
    nova secgroup-add-rule $SECGROUP icmp -1 -1 0.0.0.0/0
    nova secgroup-add-rule $SECGROUP tcp 22 22 0.0.0.0/0
}

function boot_vm_with_floating {
    # create floating ip
    ip=$(nova floating-ip-list | grep $EXT | awk '{if ($6 == "-") print $4}')
    if [[ $ip ]] ; then
        echo "Unassigned floating ip $ip exists, will use it"
    else
        nova floating-ip-create
        echo "Created floating ip $ip"
    fi
    NET_ID=$(neutron net-list | grep "$INT" | awk '{print $2}')
    nova boot "$VM" --flavor m1.tiny --image "$IMG" --nic net-name=$INT --security-groups $SECGROUP
    nova floating-ip-associate $VM $ip
}

#create_ext_net
create_int_net
create_router
create_secgroup_nova
boot_vm_with_floating
