# Blue OS ISO builder

## Blue OS App Suite

```text
apps/
  blue_store/
    pubspec.yaml
    lib/catalog.dart, lib/store_model.dart, lib/main.dart
    assets/catalog/apps.fa.json
    assets/icons/placeholder.svg, assets/screens/placeholder.svg
    test/catalog_test.dart, test/store_widget_test.dart
  blue_files/
    pubspec.yaml
    lib/file_service.dart, lib/files_model.dart, lib/main.dart
    test/files_widget_test.dart
  blue_terminal/
    pubspec.yaml
    lib/command_policy.dart, lib/terminal_model.dart, lib/main.dart
    test/command_policy_test.dart, test/terminal_widget_test.dart
packages/
  blue_ui/pubspec.yaml, blue_ui/lib/blue_ui.dart
  blue_system/pubspec.yaml, blue_system/lib/blue_system.dart
  blue_system/test/blue_system_test.dart
tools/bootstrap.sh, tools/build_all.sh, tools/package_deb.sh
```

The `apps/` monorepo contains Blue Store, Blue Files, and Blue Terminal.
`packages/blue_ui` supplies the navy/cyan widget system and Persian-first
language switch; `packages/blue_system` supplies shell-free processes and
validated package operations. No server or telemetry is used. Blue Terminal
is a command runner, **not a PTY emulator**. The catalog is local JSON; app
installation requires Internet access. SVG sample assets are placeholders.

### Linux setup

On Ubuntu 24.04 x86_64 install Flutter 3.x stable. Do not run Flutter as root.
The official SDK installation guide is recommended; a Git-based option is:

```bash
sudo apt update
sudo apt install -y git curl unzip xz-utils zip clang cmake ninja-build \
  pkg-config libgtk-3-dev libstdc++-12-dev dpkg-dev
mkdir -p "$HOME/develop"
git clone -b stable https://github.com/flutter/flutter.git "$HOME/develop/flutter"
export PATH="$HOME/develop/flutter/bin:$PATH"
flutter doctor -v
flutter config --enable-linux-desktop
chmod +x tools/*.sh
./tools/bootstrap.sh
```

Add the PATH line to your shell profile. Bootstrap generates Linux runner
files with `flutter create` only if absent, then fetches dependencies without
overwriting the authored Dart files or pubspecs.

From the project root, run and test each app:

```bash
(cd apps/blue_store && flutter run -d linux)
(cd apps/blue_files && flutter run -d linux)
(cd apps/blue_terminal && flutter run -d linux)
(cd packages/blue_system && dart pub get && dart test)
for app in blue_store blue_files blue_terminal; do (cd "apps/$app" && flutter test); done
./tools/build_all.sh
./tools/package_deb.sh blue_store
./tools/package_deb.sh blue_files
./tools/package_deb.sh blue_terminal
```

`build_all.sh` tests, builds release bundles, and produces `.deb` files in
`dist/`. Install with `sudo apt install ./dist/blue-os-store_0.1.0_amd64.deb`
(similarly Files/Terminal). Inspect dynamic libraries using
`ldd apps/blue_store/build/linux/x64/release/bundle/blue_store`.

**ISO integration:** Build `.deb` files on Ubuntu 24.04. Copy them into the
ISO chroot before squashfs generation, then use
`apt-get install -y /tmp/blue-os-*_amd64.deb` with network access. Remove
the ISO's placeholder Store/Files/Terminal launchers to avoid duplicate menu
entries. Do this before `update-initramfs` in `build_blue_os.sh`. The apps run
unprivileged; Store uses `pkexec` for APT and system Flatpak changes.
Integration is not automatically enabled in the ISO builder.

---

Builds a custom Ubuntu 24.04 LTS (Noble, amd64) XFCE Live/Installer ISO. The live
session uses Casper; Calamares installs the squashfs to a VM disk. The ISO has an
ISOLINUX BIOS entry, a standalone GRUB UEFI entry, and an isohybrid MBR/GPT layout.

## Build on Linux

Use an **x86_64 Ubuntu 24.04 host** or a comparably capable native Linux host
with root access and mount support. This does not build natively in PowerShell,
Windows, or a WSL installation without working virtualization/mount privileges.
Allow at least 12 GiB free space and a reliable Internet connection. The
Flathub remote is added during the build; no Flatpak applications are bundled.

```bash
sudo apt update
sudo apt install debootstrap squashfs-tools xorriso grub-efi-amd64-bin \
  grub-common isolinux syslinux-common mtools dosfstools
chmod +x build_blue_os.sh
sudo ./build_blue_os.sh
sha256sum -c blue-os-x86_64.iso.sha256
```

The script leaves `blue-os-x86_64.iso` and its SHA256 checksum in this folder.
`UBUNTU_MIRROR` can override the default Ubuntu archive mirror. The work tree
is unique per run and removed on exit. A failed build does not replace an old ISO.
The package versions follow Noble's enabled repositories at build time, not a
fixed snapshot. Review packages and test the installer before distributing an ISO.

## Boot a VM

Create a **new, disposable virtual disk** (at least 25 GiB), give the guest 4 GiB
RAM and two CPUs, and disable Secure Boot for this unsigned custom ISO.

- **VirtualBox:** New Linux / Ubuntu (64-bit) VM; attach the ISO to its optical
  drive. BIOS works by default. To test UEFI, enable *System > Motherboard >
  Enable EFI* before starting the VM.
- **VMware:** New Ubuntu 64-bit VM; attach the ISO as a CD/DVD and select BIOS
  or UEFI in the VM firmware options.
- **QEMU BIOS:**

```bash
sudo apt install qemu-system-x86 qemu-utils ovmf
qemu-img create -f qcow2 blue-os-test.qcow2 25G
qemu-system-x86_64 -enable-kvm -m 4096 -smp 2 \
  -drive file=blue-os-test.qcow2,format=qcow2 \
  -cdrom blue-os-x86_64.iso -boot d
```

For QEMU UEFI, add
`-drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd`
and a writable copy of `OVMF_VARS_4M.fd` as a second pflash drive. The
firmware paths vary by distro. With no KVM, omit `-enable-kvm`.

Choose **Start Blue OS**, then select **Install Blue OS** on the live desktop.
Calamares' *Erase disk* choice erases the **selected virtual disk**. Verify its
identity before confirming. The live `blueos` session autologs in and has
passwordless sudo; the installed system instead creates a password-protected
account in Calamares and removes the live autologin and sudo override. Eject
the ISO before rebooting the installed VM.

## Notes

- Blue Store is a clearly labeled placeholder UI; `flatpak search NAME` and
  `flatpak install flathub APP_ID` work against the configured Flathub remote.
- The desktop uses Adwaita-dark, Papirus-Dark, Inter, JetBrains Mono, an SVG
  wallpaper and a Plank dock. XFCE screensaver handles locking.
- No Secure Boot signature is supplied. BIOS and UEFI **VM boots must be tested**
  on an actual Linux build host; static checks alone cannot prove bootability.
- This is a distribution engineering starter, not an official Ubuntu flavor.
  For publishing, add a reproducible package manifest, signing, accessibility
  review, licensing review, release QA, and automated BIOS/UEFI install tests.
