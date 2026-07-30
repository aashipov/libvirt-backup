# Headful Linux

*nix desktop applications are designed for X Window System, a few - Wayland, most of - Xwayland compatible.

With RDP & VNC - a graphical desktop-sharing systems - one can control a remote computer from another device (RDP lacks simultaneous access VNC got, but looks more production-ready).

Debian is fast, stable and open-licensed, makes a good Operating System for virtualization host & guests.

## Host Requirements

- Virtualization-capable CPU
- 16+ GiB RAM
- 100+ GiB disk
- libvirt ≥ 7.2.0
- QEMU ≥ 4.2
- virt-manager to harness Virtual Machines

## Prototype image

Favor [Debian installer](https://cdimage.debian.org/debian-cd/current/amd64/iso-dvd/), as [Live](https://www.debian.org/CD/live/) images bring a lot of irrelevant packages

Create a disk

```shell 
qemu-img create -f qcow2 debian.qcow2 32G
```

Create a VM, 4G memory, attach the disk as VirtIO, attach DVD ISO, follow the installer (e.g., pick a package manager network mirror; install SSH server & standard system utilities)

## Packages

Debian comes with no `sudo`, so use `su -` for first steps.

Enable package manager mirror, if not done before. For Debian 13 (Trixie) it may look like:

```shell
cat << 'EOF' | tee /etc/apt/sources.list
deb http://deb.debian.org/debian trixie main contrib non-free
deb-src http://deb.debian.org/debian trixie main contrib non-free

deb http://deb.debian.org/debian-security/ trixie-security main contrib non-free
deb-src http://deb.debian.org/debian-security/ trixie-security main contrib non-free

deb http://deb.debian.org/debian trixie-updates main contrib non-free
deb-src http://deb.debian.org/debian trixie-updates main contrib non-free
EOF
```

Do `apt-get update && apt-get -y upgrade`, then `apt-get install -y sudo qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager weston winpr3-utils xrdp xorgxrdp openbox mc chromium firefox-esr thunar xfce4-terminal xfce4-taskmanager mousepad`

Add an unprivileged user `user` to `sudo` and `libvirt` groups: `usermod -aG sudo user && usermod -aG libvirt user`

Exit `su -` and SSH session, re-login.

## Configuration

Enable and start `libvirtd` and `xrdp`:

```shell
sudo systemctl enable --now libvirtd
sudo systemctl enable --now xrdp
```

At this point you should be able to RDP the Openbox in guest vm via `mstsc.exe`, `xfreerdp`/`wlfreerdp`, `Remmina` (Note: modern distros include `xfreerdp3`/`wlfreerdp3`, so craft symlinks in `/usr/bin` by hand):

```shell
xfreerdp /w:1600 /h:900 +clipboard /u:<user> /p:<password> /v:<IP> /port:3389
```

Right click to see Openbox menu

### Weston

Deploy [weston-runner](./weston-runner) to guest, launch via SSH

Use RDP client to connect to Weston at 3390 port:

```shell
xfreerdp /w:1600 /h:900 +clipboard /u:<user> /p:<password> /v:<IP> /port:3390
```

Weston got no menu, so use terminal `setsid virt-manager &` to launch `virt-manager` and detach it from terminal window

## Wrap up

Turn off the VM, navigate to the directory with disk we created `debian.qcow2`, compact the image:

```shell
qemu-img convert -O qcow2 -c debian.qcow2 debian-prototype.qcow2
```

Use `debian-prototype.qcow2` copies for integration tests VM and its guests
