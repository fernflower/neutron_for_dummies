#!/bin/sh
ROUTER_NAME=${1:-"router_EW!"}

source openrc
ROUTER_ID=$(neutron router-list | grep $ROUTER_NAME | awk '{print $2}')
if [[ -z $ROUTER_ID ]]; then 
    echo "No router $ROUTER_NAME found, exiting"
    exit 0
fi

echo "Router to delete - $ROUTER_ID"
# list all interfaces
ROUTER_PORTS=$(neutron router-port-list $ROUTER_ID |  awk '{if ($2 && $2 != "id") {print $2}}')
IFS=', ' read -a array <<< $ROUTER_PORTS

# remove ports
for port in "${array[@]}"
do
    echo "Removing interface $port"
    neutron router-interface-delete $ROUTER_ID "port=$port"
done

# remove router
neutron router-delete $ROUTER_ID

# list routers as proof of router deletion
neutron router-list
