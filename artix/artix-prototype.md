With the most recent base openrc ISO

```sh
sudo rc-service sshd start
ssh artix@u
sudo fdisk /dev/vda
```
o n p w

```sh
sudo mkfs.xfs -n ftype=1 /dev/vda1
sudo mount /dev/vda1 /mnt
sudo basestrap /mnt base base-devel openrc elogind-openrc linux grub qemu-guest-agent qemu-guest-agent-openrc sudo vim networkmanager networkmanager-openrc openssh openssh-openrc xfsprogs
fstabgen -U /mnt | sudo tee /mnt/etc/fstab
artix-chroot /mnt
```

Inside artix-chroot

```sh
grub-install --target=i386-pc /dev/vda
grub-mkconfig -o /boot/grub/grub.cfg
useradd -m admin
passwd admin
usermod -aG wheel admin
ln -s /usr/bin/vim /usr/bin/vi
visudo
rc-update add NetworkManager default
rc-update add sshd default
rc-update add qemu-guest-agent default
```