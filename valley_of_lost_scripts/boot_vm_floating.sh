#!/bin/sh
if [ -z "$INCLUDED" ]; then
    echo "Setting script-specific variables"
    OPENRC="/root/keystonerc"
    EXT="floating-ips"
    INT="mydemo"
    SECGROUP="ovsfw_sg"
    ROUTER="demo-router"
    INT_GATEWAY="20.10.0.1"
    INT_CIDR="20.10.0.0/24"
    VM="vm-$RANDOM"
    #IMG="ubuntuvm"
    IMG="TestVM"
    IMG_SRC="https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img"
    KEY="testkey"
    PUB_KEY_LOC="~/.ssh/id_rsa.pub"
    IPERF_PORT="9999"
    FLAVOR="m1.small"
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
    net_id=$(openstack network show  mydemo -c id | grep 'id' | awk '{print $4}')
    openstack server create \
        --flavor "$FLAVOR" \
        --image "$IMG" \
        --nic net-id="$net_id" \
        --security-group "$SECGROUP" \
        --key-name "$KEY" \
        --wait \
        "$VM"
    # Assign floating ip
    vm_addr="$(openstack server show "$VM" -c addresses | grep addresses| awk '{print $4}'| sed -e 's/.*=//g')"
    vm_port="$(openstack port list --network "$INT" | grep "$vm_addr" | awk '{print $2}')"
    echo "Booted vm's port on internal network is $vm_port"
    fip="$(openstack floating ip list | awk '$6 == "None" {print $4}' | head -n 1)"
    if ! [[ $fip ]]; then
        echo "No floating ip to use found, creating one.."
        fip=$(openstack floating ip create "$EXT" -c floating_ip_address | grep floating_ip_address | awk '{print $4}')
    fi
    echo "Assosiating floating ip $fip with vm $VM($vm_port)"
    openstack server add floating ip "$VM" "$fip"
    echo "VM $VM (security group $SECGROUP) can be accessed by $fip"
}

add_ubuntu_image
add_key
create_int_net
create_router
create_secgroup_neutron
boot_vm_with_floating
