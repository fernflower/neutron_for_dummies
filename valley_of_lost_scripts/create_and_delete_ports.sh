#!/bin/sh

source openrc

function delete_ports() {
    SUBNET_IDS=$(neutron subnet-list --name=subnetstorm | awk '{if ($2 && $2!="id") {print $2}}');
    for snid in $SUBNET_IDS; do
        echo "Deleting ports for $snid (subnetstorm)"
        for portid in $(neutron port-list | grep $snid | awk '{print $2}'); do
            echo "Deleting port $portid"
            neutron port-delete $portid
        done;
    done
}


function create_and_delete_ports() {
    # add resource deletion at the beginning for the script to be idempotent

    # remove old ports 
    delete_ports
    # remove old subnet(s)
    for snid in $SUBNET_IDS; do
        echo "Deleting subnet $snid (subnetstorm)"
        neutron subnet-delete $snid
    done;
    # remove old network(s) with the name netstorm
    for nid in $(neutron net-list --name=netstorm | awk '{if ($2 && $2!="id") {print $2}}'); do
        echo "Deleting network $nid (netstorm)"
        neutron net-delete $nid
    done;

    # try to reproduce rally create_and_delete_port scenario
    PORTS_NUM=${PORTS_NUM:-1}
    neutron net-create netstorm
    neutron subnet-create netstorm 192.168.2.0/24 --name subnetstorm
    # create ports
    for i in $(seq 1 $PORTS_NUM); do
        echo "Creating port $i"
        neutron port-create netstorm
    done
    # now remove ports
    delete_ports
}


function delete_nets {
    neutron subnet-delete subnetstorm
    neutron net-delete netstorm
}

create_and_delete_ports 1
delete_nets
