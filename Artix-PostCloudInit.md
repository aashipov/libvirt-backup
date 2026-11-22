As of Nov 2026, cloud-init refers systemctl (which is missing from openrc flavor)

Post Cloud-init (`root/root`, `admin/admin`)

Install `gptfdisk` (`sgdisk`)

```sh
qemu-img create -f qcow2 -o compression_type=zstd artix-post-cloud-init-builder.qcow2 32G
sudo modprobe nbd max_part=8
sudo qemu-nbd -c /dev/nbd0 ./artix-post-cloud-init-builder.qcow2
sudo sgdisk --align-end \
  --clear \
  --new 0:0:+1M --typecode=0:ef02 --change-name=0:'BIOS boot partition' \
  --new 0:0:+300M --typecode=0:ef00 --change-name=0:'EFI system partition' \
  --new 0:0:0 --typecode=0:8304 --change-name=0:'Arch Linux root' \
  /dev/nbd0
sudo qemu-nbd --disconnect /dev/nbd0
```

With the latest [iso](https://mirrors.dotsrc.org/artix-linux/iso/)

Q35, EFI

```sh
sudo rc-service sshd start
ssh artix@u
```

```sh
sudo mkfs.fat -F 32 -S 4096 /dev/vda2
sudo mkfs.xfs -f -n ftype=1 /dev/vda3
sudo mount -t xfs /dev/vda3 /mnt
sudo mount --mkdir /dev/vda2 /mnt/efi
```

```sh
sudo basestrap /mnt base openrc elogind-openrc linux grub qemu-guest-agent qemu-guest-agent-openrc sudo vim networkmanager networkmanager-openrc openssh openssh-openrc xfsprogs efibootmgr
fstabgen -U /mnt | sudo tee /mnt/etc/fstab
artix-chroot /mnt
```

Inside artix-chroot

```sh
grub-install --target=i386-pc /dev/vda
grub-install --target=x86_64-efi --efi-directory=/efi --removable
grub-mkconfig -o /boot/grub/grub.cfg
useradd -m admin
passwd admin
usermod -aG wheel admin
ln -s /usr/bin/vim /usr/bin/vi
visudo
passwd
rc-update add NetworkManager default
rc-update add sshd default
rc-update add qemu-guest-agent default
printf 'artix\n' > /etc/hostname
pacman -Scc
rm -f /etc/ssh/ssh_host_*
truncate -s 0 /etc/machine-id
history -c
exit
sudo shutdown -h now
```

Fabricate a post-cloud-init image

```sh
qemu-img convert -O qcow2 -c -o compression_type=zstd artix-post-cloud-init-builder.qcow2 artix-base-openrc-20261102-x86_64-post-cloud-init.qcow2
```