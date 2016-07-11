#!/bin/sh

source openrc
nova boot VM --flavor m1.tiny --image "TestVM" --nic net-name=admin_internal_net
