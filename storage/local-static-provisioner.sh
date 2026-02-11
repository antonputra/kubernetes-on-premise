#!/bin/bash

# Prepare local disks

export DISK_SIZE="50G"
export DISK_NAME=$(sudo lsblk --json | jq -r --arg size "$DISK_SIZE" '.blockdevices[] | select(.type == "disk" and .size == $size and .ro == false) | .name')
echo $DISK_NAME

sudo mkdir -p /mnt/disks/$DISK_NAME
sudo mkfs.xfs /dev/$DISK_NAME
sudo mount -o defaults /dev/$DISK_NAME /mnt/disks/$DISK_NAME

export DISK_UUID=$(sudo lsblk --fs --json | jq -r --arg name "$DISK_NAME" '.blockdevices[] | select(.name == $name) | .uuid')
echo "/dev/disk/by-uuid/$DISK_UUID /mnt/disks/$DISK_NAME xfs defaults 0 1" | sudo tee -a /etc/fstab
cat /etc/fstab
