With the latest [Everything iso](https://redos.red-soft.ru/product/downloads)

Q35, EFI

```sh
qemu-img create -f qcow2 -o compression_type=zstd redos-cloud-init-builder.qcow2 4G
sudo modprobe nbd max_part=8
sudo qemu-nbd -c /dev/nbd0 redos-cloud-init-builder.qcow2
sudo sgdisk --align-end \
  --clear \
  --new 0:0:+1M --typecode=0:ef02 --change-name=0:'BIOS boot partition' \
  --new 0:0:+300M --typecode=0:ef00 --change-name=0:'EFI system partition' \
  --new 0:0:0 --typecode=0:8304 --change-name=0:'Arch Linux root' \
  /dev/nbd0
sudo qemu-nbd --disconnect /dev/nbd0
```

`/dev/vda2` `/boot/efi` EFI System Partition

`/dev/vda3` `/` xfs

`Server Minimal`

'root/root' with SSH access

After reboot

```sh
dnf -y upgrade
reboot
rpm -qa | grep -E "firmware|cockpit|alsa|man-db|man-pages|plymouth" | xargs dnf -y remove
dnf -y install cloud-init cloud-utils-growpart qemu-guest-agent grub2-efi-x64 shim-x64 grub2-efi-x64-modules grub2-pc-modules which
dnf -y remove --oldinstallonly --setopt installonly_limit=2 kernel # sudo dnf remove $(dnf repoquery --installed --installonly --latest-limit=-2 -q)
grub2-install --target=i386-pc /dev/vda
grub2-mkconfig -o /boot/efi/EFI/redos/grub.cfg
grub2-mkconfig -o /boot/grub2/grub.cfg
printf 'datasource_list: [ NoCloud, ConfigDrive, None ]\n' > /etc/cloud/cloud.cfg.d/99-datasource.cfg
systemctl enable cloud-init-local cloud-init cloud-config cloud-final qemu-guest-agent
dnf -y autoremove
dnf clean all
rm -rf /var/cache/dnf/*
rm -f /etc/ssh/ssh_host_*
truncate -s 0 /etc/machine-id
cloud-init clean --logs
history -c
shutdown -h now
```

Fabricate a cloud-init image

```sh
qemu-img convert -O qcow2 -c -o compression_type=zstd redos-cloud-init-builder.qcow2 RedOS-8-20260716.0-x86_64-GenericCloud.qcow2
```
