NET_PREFIX_DHCP="mac_net_dhcp"
START_PORT_NUM=100500
SG="mac_sg"
FLAVOR="mac_sg.small"
IMAGE="damnit"
EXTERNAL="public"
EXT_BR="br-ex"
EXT_CIDR="10.90.1.0/24"
ALLOCATION_POOL_START="10.90.1.220"
ALLOCATION_POOL_END="10.90.1.230"
EXT_ROUTER="router1"


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
    for num in {0,1,2}; do
        net="$NET_PREFIX_DHCP$num"
        port_number=$(($num + $START_PORT_NUM))
        port="port$port_number"
        openstack port create --network $net $port --security-group $SG
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

function setup_firewall_sg {
    # create security group with all allowed
    exists=$(neutron security-group-list | grep $SG)
    if ! [[ $exists ]]; then
        echo "No security group $SG found"
        neutron security-group-create $SG;
        neutron security-group-rule-create $SG;
    fi

    exists=$(openstack firewall group list | grep $SG)
    if ! [[ $exists ]]; then
        echo "No firewall group $SG found"
        icmp_rule_id=$(openstack firewall group rule create --action allow --protocol icmp --name icmp_ok_$SG | grep ID | awk '{print $4}');
        icmp_policy="policy$SG"
        openstack firewall group policy create $icmp_policy --firewall-rule $icmp_rule_id;
        openstack firewall group create --name $SG --ingress-firewall-policy $icmp_policy;
    fi
    for port_id in $(neutron router-port-list $EXT_ROUTER | grep 10.0.4 | awk '{print $2}'); do
        openstack firewall group set --port $port_id $SG;
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
    # delete firewall group
    for sg_id in $(openstack firewall group list | grep $SG | awk '{print $2}'); do
        echo "Deleting firewall $sg_id..."
        openstack firewall group delete $sg_id;
    done
    # delete firewall policies
    for sg_id in $(openstack firewall group policy list | grep $SG | awk '{print $2}'); do
        echo "Deleting firewall policy $sg_id..."
        openstack firewall group policy delete $sg_id;
    done
    # delete all firewall rules
    for sg_id in $(openstack firewall group rule list | awk '{print $2}'); do
        echo "Deleting firewall rule $sg_id..."
        openstack firewall group rule delete $sg_id;
    done
    # delete security group
    for sg_id in $(neutron security-group-list | grep $SG | awk '{print $2}'); do
        neutron security-group-delete $sg_id;
    done
}

function testcase_dhcp {
    setup
    setup_firewall_sg
    create_vms_ports
    create_vms
    ping_dhcp
#    cleanup_dhcp
}

#cleanup_dhcp
setup_image_flavor
testcase_dhcp
