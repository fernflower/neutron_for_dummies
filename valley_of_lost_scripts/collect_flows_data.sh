#!/bin/sh

declare -a COMPUTES=("node-1" "node-3")
USER=root
TIMEOUT=${1:-5}
DIR=flows_data

mkdir $DIR

for compute in ${COMPUTES[@]}; do
    echo "data,flows" > "$DIR/$compute"
done;

while true; do
    for compute in ${COMPUTES[@]}; do
        filename="$DIR/$compute"
        flows=$(ssh "$USER@$compute" "sudo ovs-ofctl dump-flows br-int | wc -l");
        date="$(date +"%Y-%m-%d %T")";
        echo "$date,$flows" >> $filename;
    done;
    sleep $TIMEOUT;
done;
