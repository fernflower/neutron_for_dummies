#!/bin/sh
EXT_NAME="ext"
INT_NAME="mydemo"
ROUTER="demo-router"
EXT_POOL="start=172.18.171.86,end=172.18.171.90"
EXT_GATEWAY="172.18.171.1"
EXT_CIDR="172.18.171.0/25"
INT_GATEWAY="20.10.0.1"
INT_CIDR="20.10.0.0/24"
# too bad
ADMIN=admin
PASS=secret

function create_ext_net {
    neutron net-create "$EXT_NAME-net" --router:external True --provider:network_type local --os-username $ADMIN --os-password $PASS

    neutron subnet-create "$EXT_NAME-net" --name "$EXT_NAME-subnet" --allocation-pool $EXT_POOL --disable-dhcp --gateway $EXT_GATEWAY $EXT_CIDR --os-username $ADMIN --os-password $PASS
}

function create_int_net {
    neutron net-create "$INT_NAME-net"
    neutron subnet-create "$INT_NAME-net" --name "$INT_NAME-subnet" --gateway $INT_GATEWAY $INT_CIDR
}

function create_router {
    neutron router-create $ROUTER
    neutron router-interface-add $ROUTER "$INT_NAME-subnet"
    neutron router-gateway-set $ROUTER "$EXT_NAME-net"
}

create_ext_net
create_int_net
create_router
