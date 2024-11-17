#!/bin/bash

## Mount Disks

sudo mkdir -p /mnt/disks/sdb
sudo mkfs.xfs /dev/sdb
sudo mount -o defaults /dev/sdb /mnt/disks/sdb
sudo lsblk --fs
echo "/dev/disk/by-uuid/dae66b8e-9923-4175-b97e-2061237957b7 /mnt/disks/sdb xfs defaults 0 1" | sudo tee -a /etc/fstab
