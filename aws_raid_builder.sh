#!/bin/bash       

#==============================================================================
#title          :aws_raid_builder.sh
#description    :This script build raid from instance based disks
#author         :Thunderbird
#date           :02-08-2016
#version        :0.1    
#usage          :bash aws_raid_builder.sh
#notes          :curl,mdadm, and filesystem tools
#bash_version   :4.2.46
#==============================================================================

set -e

#VARIABLES
META_HOST="http://169.254.169.254/latest/meta-data/"
MAPPED_DEVICES="block-device-mapping/"

DEFAULT_RAID_DEV="/dev/md0"
RAID_TYPE=0
RAID_LABEL="wildfly_disk"
RAID_FS="ext4"

MOUNT_OPTS="defaults,nofail,user,owner"
MOUNT_POINT="/opt/wildfly/standalone/data"

#FUNCTIONS
build_raid(){

        for blk_dev in "${raid_blk_dev[@]}"; do
                umount -f ${blk_dev}
        done

        yes | mdadm --create --level=${RAID_TYPE} --raid-devices=${#raid_blk_dev[@]} ${DEFAULT_RAID_DEV} --force ${raid_blk_dev[@]}

        mkfs.${RAID_FS} -F ${DEFAULT_RAID_DEV}

        e2label ${DEFAULT_RAID_DEV} ${RAID_LABEL}
}

add_fstab_note(){
        echo "LABEL=\"${RAID_LABEL}\" ${MOUNT_POINT} ${RAID_FS} ${MOUNT_OPTS} 0 1" >> "/etc/fstab"
}

#MAIN_CODE
shopt -s extglob
declare -a all_blk_dev=( $(curl -s ${META_HOST}/${MAPPED_DEVICES}) )

## Removes all devices except ephemeral
declare -a local_blk_dev=( ${all_blk_dev[@]/!([eph]*)/ })

for blk_dev in "${local_blk_dev[@]}"; do
        declare -a raid_blk_dev=(${raid_blk_dev[@]}"/dev/$(curl -s ${META_HOST}/${MAPPED_DEVICES}/${blk_dev}) ")
done
shopt -u extglob

if [[ -n "${raid_blk_dev[@]}" ]]; then
        build_raid && add_fstab_note && mount -a
else
        echo "local disks not found"
fi

