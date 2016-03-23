#/bin/sh
declare -a agents=("neutron-metadata-agent" "neutron-l3-agent" "neutron-dhcp-agent" "neutron-openvswitch-agent")

for agent in "${agents[@]}"
do
    echo "disabling $agent..."
    pcs resource disable $agent
    if [ -z $1 ]; then
        sleep 3
        echo "enabling $agent..."
        pcs resource enable $agent
    fi
done
