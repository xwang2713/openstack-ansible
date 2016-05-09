# Manage Jenkins Builds with Openstack/Ansible
Launch HPCC build systems and provision with Ansible on OpenStack

## Introduction 
To better utilize Openstack resources we provide two ways to create/delete build servers on the Jenkins master:

1. HPCC Builds With Jenkins OpenStack Plugin
2. HPCC Builds With Pre-launched Build Servers 


## HPCC Builds With Jenkins OpenStack Plugin
1. Configure Jenkins Openstack Plugins in "Manage Jenkins"/"Configure System"/"Cloud (OpenStack)". Create "Cloud Instance Template" for each type of build server.
2. Provide user data for each type of build server in "Manage Jenkins"/"Managed files"/"OpenStack User Data". Sample of these files are under user-data directory with "-user-data" suffix.
3. On each HPCC build project select "Configuration Metrix"/Node/Label/Labels matched the ones defined in "Cloud Instance Template".


## Setup HPCC Builds With Pre-launched Build Servers  

### Ansible Configuration 
1. Copy /etc/ansible from this repo to /etc/ansibleo 
2. Copy .ansible.cfg to jenkins user home directory
3. Chnage OPENSTACK_ANSIBLE_HOME in environment to this repo home directory
4. Update username and password in  hpccsystem-openrc.sh 

### Use Jenkins Projects To Create/Delete Build Servers
1. Make sure the system has this repo is jenkins slave node
2. Create all needed Jenkins slave nodes for build : "Manage Jenkins"/Manage Nodes". Set the "host" field. See the rule from jenkins/Jenkins-Create-Instance-Script file.
3. Create each HPCC build project and select "Configuration Metrix"/Node/Label/Labels as "Labels" defined in each slave node.
4. Create a jenkins project to create build servers. Copy and past file jenkins/Jenkins-Create-Instance-Script file to a "Execute shell" task in "Build" section. Make moidfy  "source <path of environment file>" and uncomment it. Alternatively you can directly set OPENSTACK_ANSIBLE_HOME to this repo home directory.
5. Create a jenkins project to delete build servers. Copy and past file jenkins/Jenkins-Delete-Instance-Script file to a "Execute shell" task in "Build" section. 

Run the create project to create all defined build servers. Run the delete project to destroy all the defined build servers so the OpenStack resources can be freed.





