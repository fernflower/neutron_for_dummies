#!/bin/sh
EXT_NAME="ext1"
INT_NAME="mydemo1"
ROUTER="demo-router1"
EXT_POOL="start=192.168.0.101,end=192.168.0.200"
EXT_GATEWAY="192.168.0.1"
EXT_CIDR="192.168.0.0/24"
INT_GATEWAY="20.10.0.1"
INT_CIDR="20.10.0.0/24"
# too bad
ADMIN=admin
PASS=secret

function create_nets {
    neutron net-create "$EXT_NAME-net" --router:external True --provider:physical_network external --provider:network_type flat --os-username $ADMIN --os-password $PASS

    neutron subnet-create "$EXT_NAME-net" --name "$EXT_NAME-subnet" --allocation-pool $EXT_POOL --disable-dhcp --gateway $EXT_GATEWAY $EXT_CIDR --os-username $ADMIN --os-password $PASS

    neutron net-create "$INT_NAME-net"
    neutron subnet-create "$INT_NAME-net" --name "$INT_NAME-subnet" --gateway $INT_GATEWAY $INT_CIDR
}

function create_router {
    neutron router-create $ROUTER
    neutron router-interface-add $ROUTER "$INT_NAME-subnet"
    neutron router-gateway-set $ROUTER "$EXT_NAME-net"
}

create_nets
create_router
