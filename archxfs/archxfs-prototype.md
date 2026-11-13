Complex disk layout beyond an XFS partition makes little sense (from performance prospective for a VM with backups)

With the most recent archlinux-YYYY.MM.DD-x86_64.iso

```sh
passwd
systemctl restart sshd
ssh root@u
fdisk /dev/vda
```
o n p w

```sh
mkfs.xfs -n ftype=1 /dev/vda1
mount /dev/vda1 /mnt
pacstrap /mnt base base-devel linux grub qemu-guest-agent sudo vim networkmanager openssh
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

Inside arch-chroot

```sh
grub-install --target=i386-pc /dev/vda
grub-mkconfig -o /boot/grub/grub.cfg
useradd -m admin
passwd admin
usermod -aG wheel admin
ln -s /usr/bin/vim /usr/bin/vi
visudo
passwd
systemctl enable --now NetworkManager sshd qemu-guest-agent
pacman -Scc
```
