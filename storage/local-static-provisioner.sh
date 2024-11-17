#!/bin/bash

## Mount Disks

sudo mkdir /mnt/disks/sdb
sudo mkfs.xfs /dev/sdb
sudo mount -o defaults /dev/sdb /mnt/disks/sdb
sudo lsblk --fs
echo "/dev/disk/by-uuid/c3495fc6-2993-432c-86c1-363658d1878d /mnt/disks/sdb xfs defaults 0 1" | sudo tee -a /etc/fstab



