function setup {
    openstack network create net0
    openstack network create net1
    openstack network create net2
    openstack subnet create --network net0 --subnet-range 10.0.4.0/24 subnet0
    openstack subnet create --network net1 --subnet-range 10.0.5.0/24 subnet1
    openstack subnet create --network net2 --subnet-range 10.0.6.0/24 subnet2
}

function create_vms_ports {
    openstack port create --network net0 port0
    mac="$( openstack port show port0 | awk '/ mac_address / { print $4 }' )"
    openstack port create --network net1 --mac-address "$mac" port1
    openstack port create --network net2 --mac-address "$mac" port2
}

function create_vms {
    cirros_img="$(glance image-list | grep cirros | awk '{print $2}')"
    openstack server create --flavor 1 --image $cirros_img --nic port-id=port0  --wait vm0
    openstack server create --flavor 1 --image $cirros_img --nic port-id=port1  --wait vm1
    openstack server create --flavor 1 --image $cirros_img --nic port-id=port2  --wait vm2
    openstack server list
}

function assign_sg {
    sg="SG"
    for port in port{0,1,2}; do
        port_id=$(neutron port-list | grep $port | awk '{print $2}')
        echo "$port_id"
        neutron port-update $port_id --security-group $sg;
    done
}

function ping {
    vm0_ip="$(nova list | grep vm0 | awk '{print $12}' | sed -e 's/.*=//g')"
    vm1_ip="$(nova list | grep vm1 | awk '{print $12}' | sed -e 's/.*=//g')"
    vm2_ip="$(nova list | grep vm2 | awk '{print $12}' | sed -e 's/.*=//g')"
    # packets lost
    sudo ip netns exec "qdhcp-$( openstack network show net0 | awk '/ id / { print $4 }' )" ping -c 3 $vm0_ip
    # packets lost
    sudo ip netns exec "qdhcp-$( openstack network show net1 | awk '/ id / { print $4 }' )" ping -c 3 $vm1_ip
    # works
    sudo ip netns exec "qdhcp-$( openstack network show net2 | awk '/ id / { print $4 }' )" ping -c 3 $vm2_ip
}

# setup
# create_vms_ports
create_vms
assign_sg
#ping
