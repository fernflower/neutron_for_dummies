NET_PREFIX_DHCP="mac_net_dhcp"
NET_PREFIX_PHYS="mac_net_phys"
START_PORT_NUM=100500
SG="mac_sg"
FLAVOR="mac_sg.small"
IMAGE="damnit"
EXTERNAL="external"
EXT_BR="br-floating"
EXT_CIDR="10.90.1.0/24"
ALLOCATION_POOL_START="10.90.1.220"
ALLOCATION_POOL_END="10.90.1.230"
EXT_ROUTER="router_$EXTERNAL"


function create_external {
    if [[ $(neutron net-list | grep $EXTERNAL)  ]]; then
        echo "External network $EXTERNAL already exists, not creating one"
    else
        ext_net="$EXTERNAL"
        neutron net-create $ext_net --shared --provider:network_type flat --provider:physical_network br-floating --router:external=True
        neutron subnet-create $ext_net $EXT_CIDR --allocation-pool "start=$ALLOCATION_POOL_START,end=$ALLOCATION_POOL_END"
        neutron router-create $EXT_ROUTER
        neutron router-gateway-set $EXT_ROUTER $ext_net
    fi
}

function setup_image_flavor {
    if [[ $(glance image-list | grep $IMAGE) ]]; then
        echo "Image $IMAGE exists, not fetching one"
    else
        wget http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
	openstack image create --public --file ./cirros-0.3.5-x86_64-disk.img $IMAGE
    fi
    if [[ $(openstack flavor list | grep $FLAVOR) ]]; then
	echo "Flavor $FLAVOR exists, not creating one"
    else
	openstack flavor create --ram 1024 --disk 4 --vcpus 1 $FLAVOR
    fi
}

function setup {
    for num in {0,1,2}; do
        net="$NET_PREFIX_DHCP$num"
        subnet="subnet_$net"
        cidr="10.0.$((42 + $num)).0/24"
        openstack network create $net;
        openstack subnet create --network $net --subnet-range $cidr $subnet
        # add interface to router
        neutron router-interface-add $EXT_ROUTER $subnet
    done
}

function create_vms_ports {
    net_num=0
    net="$NET_PREFIX_DHCP$net_num"
    port="port$START_PORT_NUM"
    openstack port create --network $net $port
    mac="$( openstack port show $port | awk '/ mac_address / { print $4 }' )"
    for num in {1,2}; do
        net="$NET_PREFIX_DHCP$num"
        port_number=$(($num + $START_PORT_NUM))
        port="port$port_number"
        openstack port create --network $net --mac-address "$mac" $port
        # assign floatingip
        neutron floatingip-create --port-id $(neutron port-list | grep $port | awk '{print $2}') $EXTERNAL
    done
}

function create_vms {
    for num in {0,1,2}; do
        port="port$(( $START_PORT_NUM + $num))"
        vm="vm$port"
        openstack server create --flavor $FLAVOR --image $IMAGE --nic port-id=$port  --wait $vm
    done
    openstack server list
}

function assign_sg {
    exists=$(neutron security-group-list | grep $SG)
    if ! [[ $exists ]]; then
        echo "No security group $SG found"
        neutron security-group-create $SG;
        neutron security-group-rule-create $SG;
    fi
    for num in {0,1,2}; do
        port="port$(($START_PORT_NUM + $num))"
        port_id=$(neutron port-list | grep $port | awk '{print $2}')
        neutron port-update $port_id --security-group $SG;
    done
}

function ping_dhcp {
    for num in {0,1,2}; do
        port="port$(( $START_PORT_NUM + $num))"
        vm="vm$port"
        vm_ip="$(nova list | grep $vm | awk '{print $12}' | sed -e 's/.*=//g')"
        net="$NET_PREFIX_DHCP$num"
        sudo ip netns exec "qdhcp-$( openstack network show $net | awk '/ id / { print $4 }' )" ping -c 3 $vm_ip
    done
}

function cleanup_dhcp {
    # unassing and delete all floatings
    # XXX may affect other ips
    for fip in $(neutron floatingip-list | awk '{print $2}'); do
        neutron floatingip-delete $fip;
    done
    for num in {0,1,2}; do
        # delete vm
        port="port$(( $START_PORT_NUM + $num))"
        vm="vm$port"
        net="$NET_PREFIX_DHCP$num"
        subnet=$(neutron net-show $net -c subnets | awk '{print $4}' | tail -n2 | xargs)
        nova delete $vm
        # delete port
        neutron port-delete $port
        # delete subnet
        neutron subnet-delete $subnet
        # remove router interface
        neutron router-interface-delete $EXT_ROUTER $subnet
        # delete network
        neutron net-delete $net
    done
    # delete security-group
    for sg_id in $(neutron security-group-list | grep $SG | awk '{print $2}'); do
        echo "Deleting security group $sg..."
        neutron security-group-delete $sg_id;
    done
}

function create_phys_bridge {
    sudo ovs-vsctl add-br br-test
    sudo ovs-vsctl add-port br-test port0 -- set interface port0 type=internal
    sudo ip link add link port0 name port100 type vlan id 100
    sudo ip link add link port0 name port101 type vlan id 101
    sudo ip address add 42.42.0.3/24 dev port100
    sudo ip address add 42.42.1.3/24 dev port101
    sudo ip link set up dev port0
    sudo ip link set up dev port100
    sudo ip link set up dev port101
}

function create_phys_nets_vms {
    for num in {0,1}; do
        net="$NET_PREFIX_PHYS$num"
        subnet="subnet$num"
        cidr="42.42.$(($num)).0/24"
        vlan=$((100 + $num))
        openstack network create $net --provider-network-type vlan --provider-physical-network test --provider-segment $vlan
        openstack subnet create $subnet --network $net --subnet-range $cidr
    done
    neutron security-group-create $SG
    # allow all
    neutron security-group-rule-create $SG
    for num in {0,1}; do
        net="$NET_PREFIX_PHYS$num"
        port="port_phys$num"
        vm="vm$num"
        mac=fa:16:3e:d7:56:3d 
        openstack port create $port --network $net --mac-address fa:16:3e:d7:56:3d --security-group $SG
        openstack server create $vm --flavor $FLAVOR --image $IMAGE nic port-id=$port --wait
    done
}

function cleanup_phys_br {
    echo "Cleaning up for phys_br test"
    for num in {0,1}; do
        vm="vm$num"
        port="port_phys$num"
        net="$NET_PREFIX_PHYS$num"
        # delete vm
        nova delete $vm
        # delete port
        neutron port-delete $port
        # delete network
        neutron net-delete $net
    done
    # delete security-group
    for sg_id in $(neutron security-group-list | grep $SG | awk '{print $2}'); do
        echo "Deleting security group $sg..."
        neutron security-group-delete $sg_id;
    done
    if [[ $1 == "all" ]]; then
        echo "Deleting test-br and linux interface as well"
        sudo ip link delete port0
        sudo ovs-vsctl del-br br-test
    fi
}

function ping_phys_br {
    for num in {0,1}; do
        vm="vm$num"
        vm_ip="$(nova list | grep $vm | awk '{print $12}' | sed -e 's/.*=//g')"
        ping -c 3 $vm_ip
    done
}

function testcase_dhcp {
    setup
    create_vms_ports
    assign_sg
    create_vms
    ping_dhcp
    # cleanup_dhcp
}

function testcase_vlan_phys_br {
    create_phys_bridge
    create_phys_nets_vms
    ping_phys_br
    cleanup_phys_br
}

cleanup_dhcp
create_external
setup_image_flavor
testcase_dhcp
# testcase_vlan_phys_br
