# Blue OS — Ubuntu 24.04 Live/Installer

Blue OS builds an amd64 Casper live ISO with KDE Plasma 5.27 (the version in
Ubuntu 24.04 Noble), SDDM, a Calamares installer, Flatpak/Flathub, and the
Flutter Blue Store, Files and Terminal applications. The ISO supports legacy
BIOS (ISOLINUX) and UEFI (GRUB); disable Secure Boot for this unsigned image.
Plasma 6 would require a different base or third-party repository and is not
silently installed on Noble. The product colors are #0B132B and #00A8FF.

## Build on Ubuntu 24.04 amd64

Use a native Linux machine/VM with root and mount privileges, a stable network
connection, and ideally 15+ GiB free disk. The 5 GB preflight threshold is a
warning for CI; actual consumption depends on apt, Flutter and squashfs.
Windows PowerShell alone cannot build the ISO. Build the Flutter packages as
an ordinary user and the ISO as root:

```bash
sudo apt-get update
sudo apt-get install -y git curl unzip xz-utils zip clang cmake ninja-build \
  pkg-config libgtk-3-dev libstdc++-12-dev dpkg-dev debootstrap \
  squashfs-tools xorriso grub-efi-amd64-bin grub-common isolinux \
  syslinux-common mtools dosfstools
# Install Flutter stable with Linux desktop support (flutter doctor -v).
flutter config --enable-linux-desktop
chmod +x tools/*.sh build_blue_os.sh
./tools/build_all.sh
sudo ./build_blue_os.sh
sha256sum -c blue-os-x86_64.iso.sha256
```

`tools/bootstrap.sh` generates missing Linux Flutter runners, fetches Dart
dependencies, and `tools/build_all.sh` packages the applications in `dist/`.
Test warnings are reported but do not block packaging; review them before a
release. The ISO builder bootstraps Noble, installs Plasma and Calamares,
installs local `dist/*.deb` using `dpkg -i` followed by `apt-get -f install`,
and checks every local package. No `.deb` files means Plasma Discover is the
Blue Store fallback. A successful build writes `blue-os-x86_64.iso` and its
checksum in the project root. Set `UBUNTU_MIRROR` to override the Ubuntu
archive. Interrupted builds unmount chroot mounts and remove their temporary
workspaces; a previous ISO remains untouched on failure.

## VM validation

Create a disposable disk of 25 GiB or more with 4 GiB RAM and two vCPUs.
The *Try / Install* and *Safe graphics* entries are available for BIOS and
UEFI. Safe graphics adds `nomodeset`; for VMware MKSRenderMain trouble, also
turn off 3D acceleration in VM Display settings and retry. This is a fallback,
not a guarantee for every host GPU and VMware release.

* VirtualBox: attach ISO as optical drive; enable EFI under System/Motherboard
  for the UEFI test.
* VMware: choose Ubuntu 64-bit; attach ISO to virtual CD/DVD; test with 3D on
  and off and with Safe graphics.
* QEMU BIOS:

```bash
sudo apt-get install -y qemu-system-x86 qemu-utils ovmf
qemu-img create -f qcow2 blue-os-test.qcow2 25G
qemu-system-x86_64 -enable-kvm -m 4096 -smp 2 \
  -drive file=blue-os-test.qcow2,format=qcow2 \
  -cdrom blue-os-x86_64.iso -boot d
```

For UEFI add OVMF pflash firmware plus a writable copy of OVMF_VARS (paths
depend on the host distribution). If KVM is unavailable, omit `-enable-kvm`.
The live account `blue` autologs in with passwordless sudo. Calamares creates
the installed user's own account; the installer cleanup removes the live SDDM
autologin and sudo override. Select the **correct virtual disk** before using
Erase disk and eject the ISO after installation.

## Release checklist

- [ ] CI uploads three `.deb` packages, ISO and SHA256 checksum.
- [ ] BIOS and UEFI boot the live session and log into KDE via SDDM.
- [ ] Calamares completes both BIOS and UEFI installations and installed users can log in.
- [ ] Blue Store searches Flathub and installs `org.gnome.Calculator` online.
- [ ] VMware boots with and without 3D; Safe graphics recovers if 3D fails.
- [ ] Check Persian font, wallpaper, dock/panel, window colors and zRAM (`swapon --show`).

The image is unsigned, is not an official Ubuntu flavor, and requires real
VM/installer testing plus licensing, signing and security review before public
distribution. Static checks alone do not establish bootability.

## Desktop and Store

The first Plasma login applies the Blue OS Navy/Cyan colors, Vazirmatn font,
and US/Persian keyboard layouts (Alt+Shift switch). The live installer shortcut
uses a custom neon icon. The Store bundles 15 entries in Internet, Development,
Media and Tools categories; search can also query Flathub online. Flatpak
installs are per-user and the Run button launches installed Flatpak apps. Some
third-party Flathub entries are unofficial wrappers or require external accounts;
review each publisher and license before installing or distributing them.
