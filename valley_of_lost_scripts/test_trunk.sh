# !/bin/sh

function create_networks {
    openstack network create net0
    openstack network create net1
    openstack network create net2
    openstack subnet create --network net0 --subnet-range 10.0.4.0/24 subnet0
    openstack subnet create --network net1 --subnet-range 10.0.5.0/24 subnet1
    openstack subnet create --network net2 --subnet-range 10.0.6.0/24 subnet2
}

function create_parent_port {
    # create parent port and setup as trunk port
    parent_port=$1
    openstack port create --network net0 "$parent_port" # will become a parent port
    openstack network trunk create --parent-port "$parent_port" trunk0
}

function fetch_image_with_vlan_support {
    wget --timestamping --tries=1 https://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img
}

function create_ports {
    parent_port="port0"
    # create_parent_port "$parent_port"
    parent_mac=$(openstack port show $parent_port -c mac_address | tail -n2 | awk '{print $4}' | xargs)
    for child in {1,2}; do
        child_net="net$child"
        child_port="child_port_$child"
        vlan_id="10$child"
        openstack port create --mac-address "$parent_mac" --network "$child_net" "$child_port"
        openstack network trunk set --subport "port=$child_port,segmentation-type=vlan,segmentation-id=$vlan_id" trunk0
        echo "Booting up a server..."
        openstack server create --nic port-id="$parent_port" --wait "vm$child" --flavor=1 --image cirros-0.3.5-x86_64-disk
    # eth0 and eth0.101 have the same MAC address openstack port
    done
}

function check_connectivity {
    ssh "vm$child" sudo ip link add link eth0 name "eth0.$vlan_id" type vlan id $vlan_id
}


# create_networks
create_ports
