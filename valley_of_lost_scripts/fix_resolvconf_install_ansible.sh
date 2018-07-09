#! /bin/sh
echo "nameserver 8.8.8.8" | sudo tee --append /etc/resolv.conf
# XXX don't know what's the real problem (image?) but this is necessary
sudo dpkg --configure -a
# install ansible
sudo apt-get update
sudo apt-get install ansible
