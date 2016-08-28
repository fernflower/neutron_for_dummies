### What's this all about?
Making mos-neutron everyday devlab interaction a more pleasant experience.

### How?
Jenkins has a way to remotely trigger builds via its [Remote access API](https://wiki.jenkins-ci.org/display/JENKINS/Remote+access+API).
In short, a trivial usecase like triggering parameterized builds is performed by issuing a HTTP POST with basic access authentication.

As long as mos-neutron team uses jenkins jobs as a common way to fire up and manage virtual environments of different kinds, why
not utilize this cool feature and make UI haters life a bit easier? For those incapable of memorizing proper configuration defaults this
also brings a tempting feature to save vm/cluster configurations as ini files.

### How can I try it?
#### Learn what's yours and where it lives
A plain bash script can collect data about your virtual environments by quering neutron devlab servers. It may
require some tuning (like setting ENVNAME_PREFIX, USER and SERVERS) variables to match your defaults.

`bash ci_cli/lab_resources_usage.sh`

will output names, ips and some other specific data about actual up-and-running environments on every server.

#### Manage existing or create new environments without Jenkins UI interaction
You will need a username and Jenkins API token for this to work. Visiting [Jenkins account settings](http://networking-ci.vm.mirantis.net:8080/me/configure)
is a way to get these.

Copy user.conf.sample to user.conf, setting **env_prefix**, **user** and **token** variables. If your alias for neutron servers in /etc/hosts differs from dev_i, you may need to set proper names for dev_i servers as well.

To make life easier you can make an alias *ci* to *python ci_cli/send.py* by adding a file */usr/local/bin/ci* with the following contents:

```
#~/bin/sh
python PATH_TO_THE_CLONED_REPO/ci_cli/send.py "$@"
```

* To clean up vm environment ENV on server dev_1

`python ci_cli/send.py cleanup-vm dev_1:ENV --token TOKEN --user USER`

* To snapshot cluster environment ENV on server dev_2 as SNAP42

`python ci_cli/send.py backup-cluster dev_2:ENV --snapshot SNAP42 --token TOKEN --user USER`

* To revert cluster ENV on server dev_3 to SNAP42 state

`python ci_cli/send.py revert-cluster dev_3:ENV --snapshot SNAP42 --token TOKEN --user USER`

* To deploy a new environment

`python ci_cli/send.py deploy-vm dev_4:ENV --config ci_cli/configurations/vm_xenial --token TOKEN --user USER`

`python ci_cli/send.py deploy-cluster dev_3:ENV --config ci_cli/configurations/cluster_2nodes --token TOKEN --user USER`

#### Save configurations for future use as ini files
The existing configurations are stored in ci_cli/configurations.
Currently configurations may be passed to deploy command via --config option. Any parameter defined in config file may be overridden
by passing it on the command line as an optional argument.

* To deploy vm on server dev_4 with OS_TYPE=Ubuntu (config value Custom) and HDD_SIZE=42 (config value 50)

`python ci_cli/send.py deploy-vm dev_4:ENV --config ci_cli/configurations/vm_xenial  --token TOKEN --user USER --OS_TYPE=Ubuntu --HDD_SIZE=42`

* To make certain configuration available for deployment only on
specific servers, *servers* parameter must be specified in [jenkins] section.

```
[jenkins]
servers=dev_1,dev_3
```

* For a custom deploy job, *job* parameter in [jenkins] section can be utilized. *vm_type* and *server* will be set from ENV and SERVER parameters. For example, to run brand new deploy_9.x_cluster job on dev_4 server

```
[jenkins]
job=deploy_9.x_{vm_type}_{server}
```

`python ci_cli/send.py deploy-cluster dev_4:ENV --config ci_cli/configurations/cluster_9x_2nodes_dev12_3176 --token TOKEN --user USER`
