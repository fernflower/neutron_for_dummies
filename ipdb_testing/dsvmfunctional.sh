#!/bin/bash
envdir=".tox/dsvm-functional"

export OS_SUDO_TESTING=1
export OS_ROOTWRAP_CMD="sudo $envdir/bin/neutron-rootwrap $envdir/etc/neutron/rootwrap.conf"
export OS_ROOTWRAP_DAEMON_CMD="sudo $envdir/bin/neutron-rootwrap-daemon $envdir/etc/neutron/rootwrap.conf"
export OS_FAIL_ON_MISSING_DEPS=1
