function deploy_keepalived {
    # deploy keepalived
    salt -C 'I@keepalived:cluster' state.sls keepalived -b 1
    # check keepalived state
    salt -C 'I@keepalived:cluster' cmd.run "ip a | grep 172.16.10.2"
}

function deploy_ntp {
    # deploy NTP
    salt '*' state.sls ntp
}

function deploy_glusterfs {
    # deploy GlusterFS
    salt -C 'I@glusterfs:server' state.sls glusterfs.server.service
    salt -C 'I@glusterfs:server' state.sls glusterfs.server.setup -b 1
    # verify GlusterFS
    salt -C 'I@glusterfs:server' cmd.run "gluster peer status; gluster volume status" -b 1
}

function deploy_rabbitmq {
    # deploy rabbitmq
    salt -C 'I@rabbitmq:server' state.sls rabbitmq
    # verify rabbitmq
    salt -C 'I@rabbitmq:server' cmd.run "rabbitmqctl cluster_status"
}

function deploy_galera {
    # deploy Galera
    salt -C 'I@galera:master' state.sls galera
    salt -C 'I@galera:slave' state.sls galera
    # verify Galera
    salt -C 'I@galera:master' mysql.status | grep -A1 wsrep_cluster_size
    salt -C 'I@galera:slave' mysql.status | grep -A1 wsrep_cluster_size
}

function deploy_haproxy {
    # deploy HAProxy
    salt -C 'I@haproxy:proxy' state.sls haproxy
    salt -C 'I@haproxy:proxy' service.status haproxy
    salt -I 'haproxy:proxy' service.restart rsyslog
}

function deploy_memcached {
    # deploy memcached
    salt -C 'I@memcached:server' state.sls memcached
}

function deploy_keystone {
    salt -C 'I@keystone:server' state.sls keystone.server -b 1
    sudo salt '*' apache.signal restart
    salt -C 'I@keystone:client' state.sls keystone.client
    # mcp 1.1 doesn't have python-keystoneclient on controllers, will use osc instead
    salt -C 'I@keystone:server' cmd.run ". /root/keystonerc && openstack service list"
}

function deploy_glance {
    salt -C 'I@glance:server' state.sls glance -b 1
    salt -C 'I@glance:server' state.sls glusterfs.client
    salt -C 'I@keystone:server' state.sls keystone.server
    salt -C 'I@keystone:server' cmd.run ". /root/keystonerc; glance image-list"
}

function deploy_nova {
    salt -C 'I@nova:controller' state.sls nova -b 1
    salt -C 'I@keystone:server' cmd.run ". /root/keystonerc; nova service-list"
    ssh ctl01 "source keystonerc; nova service-list"
}

function deploy_neutron {
    salt -C 'I@neutron:server' state.sls neutron -b 1
    salt -C 'I@neutron:gateway' state.sls neutron
    salt -C 'I@keystone:server' cmd.run ". /root/keystonerc; neutron agent-list"
}

function deploy_horizon {
    salt -C 'I@horizon:server' state.sls horizon
    salt -C 'I@nginx:server' state.sls nginx
}

function deploy_proxy_nodes {
    # XXX how on earth it is supposed to be done and where?!
    # add NAT to br2
    # iptables -t nat -A POSTROUTING -o br2 -j MASQUERADE
    # echo “1” > /proc/sys/net/ipv4/ip_forward
    # iptables-save > /etc/iptables/rules.v4
    # deploy linux/openssh etc
    salt 'prx*' state.sls linux,openssh,salt
    # XXX verify connection to horizon
}

function provision_compute_nodes {
    salt '*cfg*' state.sls reclass.storage
    for num in $(seq "$COMPUTES"); do
        salt "*cmp0$num*" test.ping
    done
    # XXX damn me, this should be run till it succeeds regarding of failures
    for num in $(seq "$COMPUTES"); do
        salt "*cmp0$num*" state.highstate
    done
}

function run {
    name=$1[@];
    SERVICES=("${!name}");
    for service in ${SERVICES[@]}; do
        output="out"
        echo "Running $service...";
        eval "$service" 2>&1 > $output;
        failed=$(cat "$output" | grep 'Failed:' | awk '{if ($2 != 0) {print $2}}');
        if [[ "$failed" ]] ; then
            echo "$service failed!";
            mv out "error_$service";
            exit 1;
        else
            echo "$service finished without errors";
            rm out
        fi
    done
}

COMPUTES=2

DEPLOY_SUPPORT_SERVICES=("deploy_keepalived" "deploy_ntp" "deploy_glusterfs" "deploy_rabbitmq" \
                         "deploy_galera" "deploy_haproxy" "deploy_memcached")

DEPLOY_OPENSTACK=("deploy_keystone" "deploy_glance" "deploy_nova" "deploy_neutron" "deploy_horizon" "deploy_proxy_nodes")

DEPLOY_COMPUTES=("provision_compute_nodes")

run "DEPLOY_SUPPORT_SERVICES";
run "DEPLOY_OPENSTACK";
run "DEPLOY_COMPUTES"
