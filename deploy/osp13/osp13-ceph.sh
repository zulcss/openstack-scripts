#!/bin/bash
# cannot use unset
set -ex

if [ "$#" -ne 2 ]; then
    echo "Pass host and action as parameters" 2>&1
    echo "./$0 haa-08.ha.lab.eng.bos.redhat.com cleanup|vms|uc|oc|full" 2>&1
    exit 1
fi


HOST=$1
DATE=$(date +%Y%m%d-%H%M)
RESULTRCPT="michele@redhat.com"
ROOTDIR="/home/chuck/workspaces"
BASEDIR="$ROOTDIR/run/$HOST"
VENVDIR="$BASEDIR/venv"
LOGFILE="$BASEDIR/run.log"
SSH="ssh -t -F $BASEDIR/ssh.config.ansible undercloud"
SCP="scp -F $BASEDIR/ssh.config.ansible"
export IR_HOME=$BASEDIR

SSHCONF="$BASEDIR/.workspaces/active/ansible.ssh.config"
SSH="ssh -F $SSHCONF -l root undercloud-0"
SCP="scp -F $SSHCONF"
SSHSTACK="ssh -F $SSHCONF -l stack undercloud-0"


#TOPOLOGY_NODES=undercloud:1,controller:3,database:3,messaging:3,networker:2,compute:2,ceph:3
#TOPOLOGY_NODES=undercloud:1,controller:3,compute:1,freeipa:1
#TOPOLOGY_NODES=undercloud:1,controller:3,compute:2
TOPOLOGY_NODES=undercloud:1,controller:1,compute:1,ceph:3
#TOPOLOGY_NODES=undercloud:1,controller:3,compute:2
#TOPOLOGY_NODES=undercloud:1,controller:3,database:1
TOPOLOGY_NET=3_nets

#RHEL8URL="http://download-node-02.eng.bos.redhat.com/rel-eng/latest-RHEL-8/compose/BaseOS/x86_64/images"
#RHEL8IMG=$(curl -s $RHEL8URL/MD5SUM | grep -e "^MD5.*rhel-guest-image.*" | awk '$0=$2' FS=\( RS=\))
#IMG_URL_8="$RHEL8URL/$RHEL8IMG"
#IMG_URL_8="http://download-node-02.eng.bos.redhat.com/brewroot/packages/rhel-guest-image/8.0/1845/images/rhel-guest-image-8.0-1845.x86_64.qcow2"
IMG_URL="http://rhos-qe-mirror-qeos.usersys.redhat.com/released/RHEL-7/7.6/Server/x86_64/images/rhel-guest-image-7.6-210.x86_64.qcow2"

#MIRROR=bos
MIRROR=rdu2
SSHKEY=~/.ssh/id_rsa
VERSION=13
BUILD=z10
#BUILD=passed_phase1
#BUILD=RHOS_TRUNK-15.0-RHEL-8-20190509.n.1

# cleanup previous vms
function cleanup_host() {

  if [ -f $VENVDIR/bin/activate ]; then
  
    source $VENVDIR/bin/activate

    infrared virsh --host-address ${HOST} \
      --host-key ${SSHKEY} \
      --topology-nodes ${TOPOLOGY_NODES} \
      --topology-network ${TOPOLOGY_NET} \
      --host-memory-overcommit True \
      --image-url ${IMG_URL} \
      --cleanup yes

      rm -rf $BASEDIR
  fi

}


# [provision new vms - same command without '--cleanup']
function create_vms() {

  mkdir -p $BASEDIR                                                              
  cd $BASEDIR

  git clone https://github.com/redhat-openstack/infrared.git                     
  pushd infrared             

  # inject extraconfig templates into deploy script
  #wget https://gitlab.cee.redhat.com/pidone/infrapatches/raw/master/extraconfigpre.patch
  #git apply extraconfigpre.patch
  popd                                                                           

  virtualenv $VENVDIR                                                            
  
  source $VENVDIR/bin/activate                                                   
  pip install --upgrade pip                                                      
  pip install --upgrade setuptools                                               
  cd $BASEDIR/infrared                                                           
  pip install .  2>&1 | tee $LOGFILE    

  infrared virsh --host-address ${HOST} \
    --host-key ${SSHKEY} \
    --topology-nodes ${TOPOLOGY_NODES} \
    --topology-network ${TOPOLOGY_NET} \
    --image-url ${IMG_URL} \
    --output ${PROVISION_SETTINGS} \
    --host-memory-overcommit True \
    -e override.undercloud.disks.disk1.size=100G \
    -e override.undercloud.memory=20480 \
    -e override.controller.cpu=4 \
    -e override.controller.memory=20480 \
    -e override.ceph.cpu=2 \
    -e override.ceph.memory=8192 \
    -e override.compute.cpu=2 \
    -e override.compute.memory=16192 
}


function undercloud_install() {

  # Red Hat CA                                                                   
  #$SSH 'update-ca-trust enable; curl https://password.corp.redhat.com/RH-IT-Root-CA.crt -o /etc/pki/ca-trust/source/anchors/2015-RH-IT-Root-CA.pem; update-ca-trust extract'

  source $VENVDIR/bin/activate
  cd $BASEDIR/infrared


  infrared tripleo-undercloud \
    --version ${VERSION} \
    --images-task rpm \
    --build ${BUILD} \
    --images-packages vim,bash-completion,wget,deltarpm,strace \
    --images-cleanup True \
    --output ./uc_install.yml $1
}


function overcloud_deploy() {
  source $VENVDIR/bin/activate                                                   
  cd $BASEDIR/infrared 

  infrared tripleo-overcloud -v \
    --introspect yes \
    --tagging yes \
    --deploy  yes \
    --version $VERSION \
    --build ${BUILD} \
    --tls-everywhere no \
    --tht-roles yes \
    --storage-backend ceph \
    --deployment-files virt

}


function overcloud_testprep() {
  source $VENVDIR/bin/activate                                                   
  cd $BASEDIR/infrared 

  infrared cloud-config \
    -o cloud-config.yml \
    --mirror "rdu2" \
    --deployment-files virt \
    --tasks "create_external_network,forward_overcloud_dashboard,network_time,tempest_deployer_input" \
    --network-protocol ipv4
}


function overcloud_tempest() {
  source $VENVDIR/bin/activate                                                   
  cd $BASEDIR/infrared 

  infrared tempest -v \
    -o test.yml \
    --openstack-installer tripleo \
    --openstack-version 15-trunk \
    --image "http://rhos-qe-mirror-tlv.usersys.redhat.com/images/cirros-0.3.4-x86_64-disk.img" \
    --config-options image.http_image="http://rhos-qe-mirror-tlv.usersys.redhat.com/images/cirros-0.3.4-x86_64-uec.tar.gz" \
    --tests scenario \
    --setup rpm \
    --revision=HEAD \
    $1
}


function overcloud_ping() {
  source $VENVDIR/bin/activate
  cd $BASEDIR/infrared

  $SSHSTACK 'curl -k -O https://gitlab.cee.redhat.com/pidone/infrapatches/raw/master/pingtest.sh'
  $SSHSTACK 'sh pingtest.sh'

}

echo "Using ssh conf: $SSHCONF"

case $2 in
cleanup)
	cleanup_host
;;
vms)
	create_vms
;;
uc)
        #cleanup_host
        #create_vms
	undercloud_install
;;
oc)
	overcloud_deploy
#        overcloud_testprep
#        overcloud_ping
;;
testprep)
        overcloud_testprep
;;
tempest)
	overcloud_tempest
;;
ping)
	overcloud_ping
;;
full)
	cleanup_host
	create_vms
	undercloud_install
	overcloud_deploy
	#overcloud_testprep
	#overcloud_ping
;;
*)
	echo "please choose between cleanup|vms|uc|oc|full"
;;
esac
