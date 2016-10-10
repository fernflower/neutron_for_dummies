#!/bin/sh
if [ -z "$INCLUDED" ]; then
    echo "Setting script-specific variables"
    OPENRC="/root/openrc"
    EXT="admin_floating_net"
    INT="mydemo"
    SECGROUP="ovsfw_sg"
    ROUTER="demo-router"
    EXT_POOL="start=172.18.171.86,end=172.18.171.90"
    EXT_GATEWAY="172.18.171.1"
    EXT_CIDR="172.18.171.0/25"
    INT_GATEWAY="20.10.0.1"
    INT_CIDR="20.10.0.0/24"
    VM="vm-$RANDOM"
    #IMG="ubuntuvm"
    IMG="TestVM"
    IMG_SRC="https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img"
    KEY="testkey"
    PUB_KEY_LOC="~/.ssh/id_rsa.pub"
    IPERF_PORT="9999"
fi

source $OPENRC admin admin

function add_ubuntu_image {
    exists=$(openstack image list | grep $IMG)
    if [[ $exists ]]; then
        echo "Image $IMG exists, will use it"
        return
    fi
    wget -O xenial_image $IMG_SRC
    openstack image create $IMG  --container-format bare --public --file xenial_image
}

function add_key {
    exists=$(nova keypair-list | grep $KEY)
    if [[ $exists ]]; then
        echo "Key $KEY exists"
        return
    fi
    nova keypair-add --pub-key $PUB_KEY_LOC "$KEY"
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

function create_secgroup_neutron {
    exists=$(neutron security-group-list | grep $SECGROUP)
    if [[ $exists ]] ; then
        echo "Secutity group $SECGROUP exists, not recreating it"
        return
    fi
    neutron security-group-create $SECGROUP
    neutron security-group-rule-create --protocol icmp --direction ingress $SECGROUP
    neutron security-group-rule-create --protocol tcp --port-range-min 22 --port-range-max 22 --direction ingress $SECGROUP
    neutron security-group-rule-create --protocol udp --port-range-min $IPERF_PORT --port-range-max $IPERF_PORT --direction ingress $SECGROUP
    neutron security-group-rule-create --protocol tcp --port-range-min $IPERF_PORT --port-range-max $IPERF_PORT --direction ingress $SECGROUP
}

function boot_vm_with_floating {
    # create floating ip
    ip=$(nova floating-ip-list | grep $EXT | awk '{if ($6 == "-") print $4}' | head -1)
    if [[ $ip ]] ; then
        echo "Unassigned floating ip $ip exists, will use it"
    else
        nova floating-ip-create
        ip=$(nova floating-ip-list | grep $EXT | awk '{if ($6 == "-") print $4}')
        echo "Created floating ip $ip"
    fi
    NET_ID=$(neutron net-list | grep "$INT" | awk '{print $2}')
    nova boot "$VM" --flavor 2 --image "$IMG" --nic net-name=$INT --security-groups $SECGROUP --key $KEY --poll
    nova floating-ip-associate $VM $ip
    echo "VM $VM (security group $SECGROUP) can be accessed by $ip"
    echo "Done"
}

add_ubuntu_image
add_key
create_int_net
create_router
create_secgroup_neutron
boot_vm_with_floating
