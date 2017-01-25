#!/bin/sh
HOST="172.18.171.22"
USER=dev-user
TIMEOUT=${1:-5}
DIR=cpu_data
DATE_FORMAT="%Y-%m-%d %T"

declare -a PROCESSES=("/usr/local/bin/neutron-server"
                      "/usr/local/bin/neutron-openvswitch-agent"
                      "/usr/local/bin/nova-scheduler"
                      "/usr/local/bin/nova-conductor"
                      "/usr/local/bin/nova-compute"
                      "/var/run/openvswitch/ovs-vswitchd")

function get_log_file {
    proc=$1;
    pid=$2;
    name=$(basename "$proc");
    echo "$DIR/$pid-$name";
}

function init {
    mkdir $DIR

    for proc in ${PROCESSES[@]}; do
        proc_name=$(basename $proc);
        declare -a pids=$(pgrep -f "$proc");
        for pid in ${pids[@]}; do
            log=$(get_log_file $proc $pid);
            echo "date,cpu" > $log;
        done;
    done;
}


function collect {
    for proc in ${PROCESSES[@]}; do
        pids=$(pgrep -f $proc);
        declare -a pids=$(pgrep -f "$proc");
        for pid in ${pids[@]}; do
            date=$(date +"$DATE_FORMAT");
            cpu=$(top -b -p $pid -n1 | tail -n1 | awk '{print $9}');
            log=$(get_log_file $proc $pid);
            echo "$date,$cpu" >> $log;
        done
    done
}

init
while true; do
    collect
done;
