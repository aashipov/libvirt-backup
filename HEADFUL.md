# Headful Linux

*nix desktop applications are designed for X Window System, a few - Wayland, most of - Xwayland compatible.

With RDP & VNC - a graphical desktop-sharing systems - one can control a remote computer from another device (RDP lacks simultaneous access VNC got, but looks more production-ready).

Debian is fast, stable and open-licensed, makes a good Operating System for virtualization host & guests. Ubuntu is slower, but may work as well. Expect the very basic things like kernel upgrade to break the system (Ubuntu adds complexity of its own and inherits Debian testing, which is more error-prone than Debian stable + backports). Other distros may work as well

## Host Requirements

- Virtualization-capable CPU
- 16+ GiB RAM
- 100+ GiB disk
- Linux host: libvirt ≥ 7.2.0, QEMU ≥ 4.2, virt-manager
- Windows host: Windows 10 (Windows/Hyper-V Server 2016 Evaluation) or newer; Hyper-V with nested virtualization enabled (`Set-VMProcessor -VMName <VMName> -ExposeVirtualizationExtensions $true`)
- FreeBSD host with bhyve

## Prototype image (Linux host)

Favor [Debian installer](https://cdimage.debian.org/debian-cd/current/amd64/iso-dvd/), as [Live](https://www.debian.org/CD/live/) images bring a lot of irrelevant packages.

Create a disk

```sh
qemu-img create -f qcow2 debian.qcow2 32G
```

Create a VM, 4G memory, attach the disk as VirtIO, attach DVD ISO, follow the installer (e.g., pick a package manager network mirror; install SSH server & standard system utilities)

## Prototype image (Windows host)

Generation 1 VM, dynamic memory off, same as above

## Linux guest installation & setup

### Packages

Debian comes with no `sudo`, so use `su -` for the first steps.

Enable package manager mirror, if not done before. For Debian 13 (Trixie) it may look like:

```sh
cat << 'EOF' | tee /etc/apt/sources.list
deb http://deb.debian.org/debian trixie main contrib non-free
deb-src http://deb.debian.org/debian trixie main contrib non-free

deb http://deb.debian.org/debian-security/ trixie-security main contrib non-free
deb-src http://deb.debian.org/debian-security/ trixie-security main contrib non-free

deb http://deb.debian.org/debian trixie-updates main contrib non-free
deb-src http://deb.debian.org/debian trixie-updates main contrib non-free
EOF
```

```sh
apt-get update && apt-get -y upgrade
apt-get install -y cron git rsync acl sudo qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager weston winpr3-utils xrdp xorgxrdp openbox mc chromium firefox-esr thunar xfce4-terminal xfce4-taskmanager mousepad
apt clean && apt autoremove
systemctl enable --now cron
```

Add an unprivileged user `user` to `sudo` and `libvirt` groups:

```sh
usermod -aG sudo user && usermod -aG libvirt user
```

Exit `su -` and SSH session, re-login.

### Configuration

Enable and start `libvirtd` and `xrdp`:

```sh
sudo systemctl enable --now libvirtd
sudo systemctl enable --now xrdp
```

Configure Openbox (open terminal on Win+Enter/Return, quit Openbox on Ctrl+Alt+BackSpace):

Deploy `openbox-rc.xml` to home dir.

```sh
mkdir -p ~/.config/openbox
mv ~/openbox-rc.xml ~/.config/openbox/rc.xml
```

At this point you should be able to RDP the Openbox in guest vm via `mstsc.exe`, `xfreerdp`/`wlfreerdp`, `Remmina` (Note: modern distros include `xfreerdp3`/`wlfreerdp3`, so craft symlinks in `/usr/bin` by hand):

```sh
xfreerdp /w:1600 /h:900 +clipboard /u:<user> /p:<password> /v:<IP> /port:3389
```

Right click to see Openbox menu

### Weston

Deploy [weston-runner](./weston-runner) to guest, launch via SSH

Use RDP client to connect to Weston at 3390 port:

```sh
xfreerdp /w:1600 /h:900 +clipboard /u:<user> /p:<password> /v:<IP> /port:3390
```

Weston got no menu, so use terminal `setsid virt-manager &` or [gui](./gui) wrapper to launch `virt-manager` and detach it from terminal window

### libvirtd & virsh configuration

'Nested' virtualization fails with Debian (host & guest network address spaces `192.168.122.0/24` clash):
use `sudo virsh net-edit default` to switch `nested` network to `192.168.123.0/24` or alike

Configure networks startup (must) `sudo virsh net-autostart default && sudo virsh net-start default`

Configure userspace libvirt (should, convenience):

```sh
mkdir -p ${HOME}/.config/libvirt/
cat << 'EOF' | tee -a ${HOME}/.config/libvirt/libvirt.conf
uri_default = "qemu:///system"
EOF
```

## Wrap up

Turn off the VM, navigate to the directory with disk we created `debian.qcow2`, compact the image:

```sh
qemu-img convert -O qcow2 -c debian.qcow2 debian-prototype.qcow2
```

Use `debian-prototype.qcow2` copies for integration tests VM and its guests
