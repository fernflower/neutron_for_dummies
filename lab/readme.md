### What's this all about?
Making mos-neutron everyday devlab interaction a more pleasant experience. 

### How?
Jenkins has a way to remotely trigger builds via its [Remote access API](https://wiki.jenkins-ci.org/display/JENKINS/Remote+access+API). 
In short, a trivial usecase like triggering parameterized builds is performed by issuing a HTTP POST with basic access authentication.

As long as mos-neutron team uses jenkins jobs as a common way to fire up and manage virtual environments of different kinds, why 
not utilize this cool feature and make UI haters life a bit easier? For those incapable of memorizing proper configuration defaults this 
also brings a tempting feature to save vm/cluster configurations as an ini files.

### How can I try it?
#### Learn what's yours and where it lives
A plain bash script can collect data about your virtual environments by quering neutron devlab servers. It may 
require some tuning (like setting ENVNAME_PREFIX, USER and SERVERS) variables to match your defaults.

`bash lab_resources_usage.sh`

will output names, ips and some other specific data about actual up-and-running environments on every server.

#### Manage existing or create new environments without Jenkins UI interaction
You will need a username and Jenkins API token for this to work. Visiting [Jenkins account settings](http://networking-ci.vm.mirantis.net:8080/me/configure)
is a way to get these.

* To clean up vm environment ENV on server dev_1

`python lab/send.py cleanup-vm dev_1:ENV --token TOKEN --user USER` 

* To snapshot cluster environment ENV on server dev_2 as SNAP42

`python lab/send.py backup-cluster dev_2:ENV --snapshot SNAP42 --token TOKEN --user USER` 

* To revert cluster ENV on server dev_3 to SNAP42 state

`python lab/send.py revert-cluster dev_3:ENV --snapshot SNAP42 --token TOKEN --user USER` 

* To deploy a new environment (only vms available at the moment)

`python lab/send.py deploy-vm dev_4:ENV --config lab/configurations/vm_xenial --token TOKEN --user USER`


#### Save configurations for future use as ini files
The existing configurations are stored in lab/configurations. 
Currently configurations may be passed to deploy command via --config option. Any parameter defined in config file may be overridden
by passing it on the command line as an optional argument.

* To deploy vm on server dev_4 with OS_TYPE=Ubuntu (config value Custom) and HDD_SIZE=42 (config value 50)

`python lab/send.py deploy-vm dev_4:ENV --config lab/configurations/vm_xenial  --token TOKEN --user USER --OS_TYPE=Ubuntu --HDD_SIZE=42`

