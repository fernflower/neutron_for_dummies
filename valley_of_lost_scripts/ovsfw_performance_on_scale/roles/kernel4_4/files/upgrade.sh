#!/bin/bash
set -e

ENVS=${1:?}

if [ "${ENVS}" == "all" ]; then
    ENVS="$(fuel2 env list -c id -f value)"
fi

for eid in ${ENVS}; do
    cd /tmp
    fuel env --env $eid --attributes --download
    # Change kernel and headers, remove unused dkms packages
    sed -i -e 's/generic-lts-trusty/generic-lts-xenial/g' \
        -e '/^\([[:blank:]]*\)hpsa-dkms$/d' cluster_${eid}/attributes.yaml
    fuel env --env $eid --attributes --upload
    # Remove old IBP
    rm -vf "/var/www/nailgun/targetimages/env_${eid}_*"
done

sed -i '/osd_mount_options_xfs/s/delaylog,//g' /etc/puppet/modules/osnailyfacter/manifests/globals/globals.pp

for f in /usr/share/fuel-openstack-metadata/openstack.yaml \
    /usr/lib/python2.7/site-packages/fuel_agent/drivers/nailgun.py \
    /usr/lib/python2.7/site-packages/nailgun/fixtures/openstack.yaml; do
sed -i -e 's/generic-lts-trusty/generic-lts-xenial/g' -e '/^\([[:blank:]]*\)\("*\)hpsa-dkms/d' ${f}

done

systemctl restart nailgun #Is astute should be restarted?

fuel-bootstrap -v --debug build --activate --kernel-flavor linux-image-generic-lts-xenial --label kernel44 

echo "All done"
