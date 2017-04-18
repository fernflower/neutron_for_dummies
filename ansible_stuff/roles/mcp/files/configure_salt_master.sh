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

deploy_keepalived
deploy_ntp
deploy_glusterfs
deploy_rabbitmq
deploy_galera
deploy_haproxy
deploy_memcached
