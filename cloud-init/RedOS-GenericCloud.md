With the latest [Everything iso](https://redos.red-soft.ru/product/downloads)

i440FX, BIOS

```sh
qemu-img create -f qcow2 -o compression_type=zstd redos-cloud-init-builder.qcow2 4G
```

GPT partition table

Unformatted EF02 (bios_grub) partition 1MiB
`/` xfs the rest

`Server Minimal`

'root/root' with SSH access

After reboot

```sh
dnf -y upgrade
dnf -y install cloud-init cloud-utils-growpart qemu-guest-agent
printf 'datasource_list: [ NoCloud, ConfigDrive, None ]\n' > /etc/cloud/cloud.cfg.d/99-datasource.cfg
systemctl enable cloud-init-local cloud-init cloud-config cloud-final qemu-guest-agent
dnf clean all
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
