#!/bin/sh

# try dump-flows at a random node
if ssh root@node-1 ovs-ofctl dump-flows br-int; then
    OF_OPTS=""
else
    OF_OPTS="-O OpenFlow13"
fi

for h in node-{1,2,3,4}; do 
    for br in $(ssh root@$h ovs-vsctl show|grep Bridge|grep -o 'br-.*'); do 
        echo $h:$br; ssh root@$h ovs-ofctl dump-flows $br $OF_OPTS; 
        echo =============; echo;
     done;
done;
