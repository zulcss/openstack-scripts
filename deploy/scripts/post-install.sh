#!/bin/bash

echo "Fetch images"
mkdir -p ~/images
curl -o ~/images/CentOS-7-x86_64-GenericCloud.qcow2 http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2
curl -o ~/images/rhel-guest-image-7.6-210.x86_64.qcow2 http://rhos-qe-mirror-qeos.usersys.redhat.com/released/RHEL-7/7.6/Server/x86_64/images/rhel-guest-image-7.6-210.x86_64.qcow2

source ~/overcloudrc

echo "Setup flavors"
openstack flavor create m1.xtiny --vcpus 1 --ram 64 --disk 1
openstack flavor create m1.tiny-centos --vcpus 1 --ram 192 --disk 8
openstack flavor create m1.tiny --vcpus 1 --ram 512 --disk 1
openstack flavor create m1.small --vcpus 1 --ram 2048 --disk 20
openstack flavor create m1.medium --vcpus 2 --ram 4096 --disk 40
openstack flavor create m1.large --vcpus 4 --ram 8192 --disk 8192
openstack flavor create m1.xlarge --vcpus 8 --ram 16384 --disk 160

echo "Setup admin quotats"
openstack quota set --properties -1 --server-groups -1 \
    --ram -1 --key-pairs -1 --instances -1 --fixed-ips -1 \
    --injected-file-size -1 --server-group-members -1 \
    --injected-files -1 --cores -1 --injected-path-size -1 \
    --gigabytes -1 --snapshots -1 --volumes -1  --subnetpools -1 \
    --ports -1 --subnets -1  --networks -1 --floating-ips -1 \
    --secgroup-rules -1 --secgroups -1 --routers -1 --rbac-policies -1 admin


echo "Setup ssh keys"
openstack keypair create key > /home/stack/key.pem
chmod 0600 /home/stack/key.pem

echo "Upload images"
openstack image create --public centos < ~/images/CentOS-7-x86_64-GenericCloud.qcow2
openstack image create --public rhel7 < ~/images/rhel-guest-image-7.6-210.x86_64.qcow2

echo "Create security groups"
openstack security group create browbeat
openstack security group rule create --ingress --protocol tcp --dst-port 22 browbeat
openstack security group rule create --ingress --protocol icmp browbeat

