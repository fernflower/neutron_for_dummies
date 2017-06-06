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
    neutron security-group-create SG;
    neutron security-group-rule-create SG;
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

function create_phys_bridge {
    sudo ovs-vsctl add-br br-test
    sudo ovs-vsctl add-port br-test port0 -- set interface port0 type=internal
    sudo ip link add link port0 name port100 type vlan id 100
    sudo ip link add link port0 name port101 type vlan id 101
    sudo ip address add 10.0.4.3/24 dev port100
    sudo ip address add 10.0.5.3/24 dev port101
    sudo ip link set up dev port0
    sudo ip link set up dev port100
    sudo ip link set up dev port101
}

function create_phys_nets_vms {
    openstack network create net0 --provider-network-type vlan --provider-physical-network test --provider-segment 100
    openstack network create net1 --provider-network-type vlan --provider-physical-network test --provider-segment 101
    openstack subnet create subnet0 --network net0 --subnet-range 10.0.4.0/24
    openstack subnet create subnet1 --network net1 --subnet-range 10.0.5.0/24
    neutron security-group-create SG;
    neutron security-group-rule-create SG;
    openstack port create port0 --network net0 --mac-address fa:16:3e:d7:56:3d --security-group SG
    openstack port create port1 --network net1 --mac-address fa:16:3e:d7:56:3d --security-group SG
    openstack server create vm0 --flavor 1 --image cirros-0.3.5-x86_64-disk --nic port-id=port0 --wait
    openstack server create vm1 --flavor 1 --image cirros-0.3.5-x86_64-disk --nic port-id=port1 --wait
}

#setup
#create_vms_ports
#create_vms
#assign_sg
#ping

create_phys_bridge
create_phys_nets_vms
