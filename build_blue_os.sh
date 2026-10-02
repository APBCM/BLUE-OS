#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
OUTPUT="$SCRIPT_DIR/blue-os-x86_64.iso"
MIRROR="${UBUNTU_MIRROR:-http://archive.ubuntu.com/ubuntu}"
WORK="" ROOT="" ISO=""
MOUNTS=()
log() { printf '[blue-os] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }
cleanup() {
    local status=$? index
    trap - EXIT INT TERM
    for ((index=${#MOUNTS[@]}-1; index>=0; index--)); do
        if mountpoint -q "${MOUNTS[index]}"; then umount -l "${MOUNTS[index]}"; fi
    done
    if [[ -n "$WORK" && "$WORK" == "$SCRIPT_DIR/.blue-os-work."* && -d "$WORK" ]]; then
        rm -rf -- "$WORK"
    fi
    if ((status)); then log "Failed ($status); previous ISO is untouched."; fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
enter() { chroot "$ROOT" /usr/bin/env DEBIAN_FRONTEND=noninteractive "$@"; }
check_host() {
    [[ $EUID -eq 0 && $(uname -s) == Linux && $(uname -m) == x86_64 ]] || die 'Run as root on x86_64 Linux.'
    [[ ! -L "$SCRIPT_DIR" && ! -L "$OUTPUT" ]] || die 'Symlinked project/output refused.'
    local tool file
    for tool in debootstrap chroot mount umount mountpoint mksquashfs xorriso grub-mkstandalone mkfs.vfat mmd mcopy sha256sum; do
        command -v "$tool" >/dev/null || die "Missing host tool $tool"
    done
    for file in /usr/lib/ISOLINUX/{isolinux.bin,isohdpfx.bin} /usr/lib/syslinux/modules/bios/{ldlinux.c32,menu.c32,libcom32.c32,libutil.c32}; do
        [[ -f "$file" ]] || die "Missing $file (install isolinux and syslinux-common)"
    done
    for file in grub.cfg isolinux.cfg wallpaper.svg blue-store.desktop blue-files.desktop blue-terminal.desktop install-blue-os.desktop blue-os-look.sh blue-os-store.sh blue-os-installer.sh calamares/{settings.conf,unpackfs.conf,packages.conf,branding.desc,users.conf,displaymanager.conf,partition.conf,cleanup.conf}; do
        [[ -f "$SCRIPT_DIR/config/$file" ]] || die "Missing config/$file"
    done
    local free_kib
    free_kib=$(df -Pk "$SCRIPT_DIR" | awk 'END {print $4}')
    ((free_kib >= 12000000)) || die 'At least 12 GiB free workspace required.'
}
mount_root() {
    mount --bind /dev "$ROOT/dev"; MOUNTS+=("$ROOT/dev")
    mkdir -p "$ROOT/dev/pts"
    mount -t devpts devpts "$ROOT/dev/pts"; MOUNTS+=("$ROOT/dev/pts")
    mount -t proc proc "$ROOT/proc"; MOUNTS+=("$ROOT/proc")
    mount -t sysfs sysfs "$ROOT/sys"; MOUNTS+=("$ROOT/sys")
    mount --bind /run "$ROOT/run"; MOUNTS+=("$ROOT/run")
}
bootstrap() {
    log 'Bootstrapping Noble.'
    debootstrap --arch=amd64 --variant=minbase noble "$ROOT" "$MIRROR"
    cp /etc/resolv.conf "$ROOT/etc/resolv.conf"
    cat > "$ROOT/etc/apt/sources.list" <<EOF
deb $MIRROR noble main restricted universe multiverse
deb $MIRROR noble-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse
EOF
    printf 'blue-os\n' > "$ROOT/etc/hostname"
    printf '127.0.0.1 localhost\n127.0.1.1 blue-os\n' > "$ROOT/etc/hosts"
    printf '#!/bin/sh\nexit 101\n' > "$ROOT/usr/sbin/policy-rc.d"
    chmod 0755 "$ROOT/usr/sbin/policy-rc.d"
    mount_root
    enter apt-get update
}
install_system() {
    log 'Installing live system and installer.'
    enter apt-get install -y --no-install-recommends \
        linux-generic systemd-sysv initramfs-tools casper sudo dbus dbus-x11 \
        network-manager netplan.io locales console-setup keyboard-configuration \
        lightdm lightdm-gtk-greeter xorg xfce4 xfce4-terminal thunar thunar-volman \
        gvfs gvfs-backends tumbler policykit-1-gnome xdg-user-dirs \
        plank papirus-icon-theme fonts-jetbrains-mono fonts-inter librsvg2-common \
        flatpak xdg-desktop-portal xdg-desktop-portal-gtk \
        ca-certificates curl zsh zenity xfce4-screensaver \
        calamares calamares-settings-ubuntu-common squashfs-tools \
        grub-pc-bin grub-efi-amd64-bin grub-efi-amd64-signed shim-signed \
        efibootmgr dosfstools parted e2fsprogs os-prober python3 python3-yaml
    enter locale-gen en_US.UTF-8
    enter update-locale LANG=en_US.UTF-8
    enter systemctl enable NetworkManager lightdm
    enter flatpak remote-add --system --if-not-exists --from flathub https://flathub.org/repo/flathub.flatpakrepo
}
configure_system() {
    log 'Applying Blue OS desktop and installer configuration.'
    mkdir -p "$ROOT/etc/calamares/branding/blueos" "$ROOT/etc/calamares/modules" \
        "$ROOT/etc/xdg/autostart" "$ROOT/etc/lightdm/lightdm.conf.d" \
        "$ROOT/etc/sudoers.d" "$ROOT/usr/share/backgrounds/blue-os" \
        "$ROOT/usr/share/applications" "$ROOT/usr/local/bin" "$ROOT/etc/skel/Desktop" \
        "$ROOT/etc/default/grub.d"
    install -m 0644 "$SCRIPT_DIR/config/wallpaper.svg" "$ROOT/usr/share/backgrounds/blue-os/wallpaper.svg"
    install -m 0644 "$SCRIPT_DIR/config/calamares/branding.desc" "$ROOT/etc/calamares/branding/blueos/branding.desc"
    install -m 0644 "$SCRIPT_DIR/config/calamares/settings.conf" "$ROOT/etc/calamares/settings.conf"
    install -m 0644 "$SCRIPT_DIR/config/calamares/unpackfs.conf" "$ROOT/etc/calamares/modules/unpackfs.conf"
    install -m 0644 "$SCRIPT_DIR/config/calamares/packages.conf" "$ROOT/etc/calamares/modules/packages.conf"
    install -m 0644 "$SCRIPT_DIR/config/calamares/users.conf" "$ROOT/etc/calamares/modules/users.conf"
    install -m 0644 "$SCRIPT_DIR/config/calamares/partition.conf" "$ROOT/etc/calamares/modules/partition.conf"
    install -m 0644 "$SCRIPT_DIR/config/calamares/displaymanager.conf" "$ROOT/etc/calamares/modules/displaymanager.conf"
    install -m 0644 "$SCRIPT_DIR/config/calamares/cleanup.conf" "$ROOT/etc/calamares/modules/blueos-cleanup.conf"
    install -m 0755 "$SCRIPT_DIR/config/blue-os-look.sh" "$ROOT/usr/local/bin/blue-os-look"
    install -m 0755 "$SCRIPT_DIR/config/blue-os-store.sh" "$ROOT/usr/local/bin/blue-os-store"
    install -m 0755 "$SCRIPT_DIR/config/blue-os-installer.sh" "$ROOT/usr/local/bin/blue-os-installer"
    local launcher
    for launcher in blue-store blue-files blue-terminal install-blue-os; do
        install -m 0644 "$SCRIPT_DIR/config/$launcher.desktop" "$ROOT/usr/share/applications/$launcher.desktop"
    done
    cp "$SCRIPT_DIR/config/install-blue-os.desktop" "$ROOT/etc/skel/Desktop/Install Blue OS.desktop"
    chmod 0755 "$ROOT/etc/skel/Desktop/Install Blue OS.desktop"
    cat > "$ROOT/etc/xdg/autostart/blue-os-look.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Blue OS desktop settings
Exec=/usr/local/bin/blue-os-look
OnlyShowIn=XFCE;
NoDisplay=true
EOF
    cat > "$ROOT/etc/casper.conf" <<'EOF'
export USERNAME="blueos"
export USERFULLNAME="Blue OS Live User"
export HOST="blue-os"
export BUILD_SYSTEM="Ubuntu"
EOF
    cat > "$ROOT/etc/lightdm/lightdm.conf.d/70-blue-os-live.conf" <<'EOF'
[Seat:*]
autologin-user=blueos
autologin-user-timeout=0
user-session=GAPGPTMASKTOKENgykkize9a9dX0X
EOF
    printf 'blueos ALL=(ALL) NOPASSWD:ALL\n' > "$ROOT/etc/sudoers.d/99-blue-os-live"
    chmod 0440 "$ROOT/etc/sudoers.d/99-blue-os-live"
    cat > "$ROOT/etc/skel/.zshrc" <<'EOF'
autoload -Uz colors && colors
PROMPT='%F{cyan}%n%f@%F{blue}%m%f %F{yellow}%~%f %# '
EOF
    printf 'GRUB_DISTRIBUTOR="Blue OS"\n' > "$ROOT/etc/default/grub.d/70-blue-os.cfg"
    : > "$ROOT/etc/machine-id"
    rm -f "$ROOT/var/lib/dbus/machine-id"
    enter update-initramfs -u -k all
}
install_local_debs() {
    local deb count=0
    local -a debs=()
    if [[ -d "$SCRIPT_DIR/dist" ]]; then
        shopt -s nullglob
        debs=("$SCRIPT_DIR"/dist/*.deb)
        shopt -u nullglob
    fi
    if ((${#debs[@]} == 0)); then
        log 'No dist/*.deb found; skipping local app installation (placeholder launchers remain).'
        return 0
    fi
    log "Installing ${#debs[@]} locally built .deb package(s) into the chroot."
    mkdir -p "$ROOT/tmp/blue-debs"
    for deb in "${debs[@]}"; do
        log "  - $(basename -- "$deb")"
        cp -f -- "$deb" "$ROOT/tmp/blue-debs/"
    done
    enter apt-get install -y --no-install-recommends /tmp/blue-debs/*.deb
    for launcher in blue-store blue-files blue-terminal; do
        if [[ ! -f "$ROOT/usr/share/applications/$launcher.desktop" ]]; then
            log "  Re-copying missing launcher: $launcher.desktop"
            install -m 0644 "$SCRIPT_DIR/config/$launcher.desktop" \
                "$ROOT/usr/share/applications/$launcher.desktop"
        fi
    done
    rm -rf "$ROOT/tmp/blue-debs"
}
make_esp() {
    local esp="$ISO/boot/efi.img"
    truncate -s 32M "$esp"
    mkfs.vfat -F 32 -n BLUEOS_EFI "$esp" >/dev/null
    mmd -i "$esp" ::/EFI ::/EFI/BOOT
    grub-mkstandalone --format=x86_64-efi --output="$WORK/BOOTX64.EFI" \
        --modules='part_gpt part_msdos fat iso9660 search normal linux' \
        "boot/grub/grub.cfg=$SCRIPT_DIR/config/grub.cfg"
    mcopy -i "$esp" "$WORK/BOOTX64.EFI" ::/EFI/BOOT/BOOTX64.EFI
}
package_iso() {
    log 'Packing squashfs and hybrid BIOS/UEFI media.'
    mkdir -p "$ISO/casper" "$ISO/isolinux" "$ISO/boot"
    local kernel index
    kernel=$(find "$ROOT/boot" -maxdepth 1 -name 'vmlinuz-*' -printf '%f\n' | sort -V | tail -1)
    [[ -n "$kernel" && -f "$ROOT/boot/initrd.img-${kernel#vmlinuz-}" ]] || die 'Kernel or initramfs missing.'
    cp "$ROOT/boot/$kernel" "$ISO/casper/vmlinuz"
    cp "$ROOT/boot/initrd.img-${kernel#vmlinuz-}" "$ISO/casper/initrd"
    rm -f "$ROOT/usr/sbin/policy-rc.d"
    enter apt-get clean
    rm -rf "$ROOT/var/lib/apt/lists/"* "$ROOT/tmp/"*
    for ((index=${#MOUNTS[@]}-1; index>=0; index--)); do umount "${MOUNTS[index]}"; done
    MOUNTS=()
    mksquashfs "$ROOT" "$ISO/casper/filesystem.squashfs" -comp xz -b 1M \
        -noappend -wildcards -e 'dev/*' 'proc/*' 'sys/*' 'run/*' 'tmp/*'
    du -sx --block-size=1 "$ROOT" | awk '{print $1}' > "$ISO/casper/filesystem.size"
    install -m 0644 "$SCRIPT_DIR/config/isolinux.cfg" "$ISO/isolinux/isolinux.cfg"
    cp /usr/lib/ISOLINUX/isolinux.bin "$ISO/isolinux/"
    cp /usr/lib/syslinux/modules/bios/{ldlinux.c32,menu.c32,libcom32.c32,libutil.c32} "$ISO/isolinux/"
    make_esp
    (cd "$ISO" && find . -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt)
    xorriso -as mkisofs -r -J -joliet-long -V BLUE_OS_NOBLE \
        -o "$WORK/blue-os-x86_64.iso" \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin -partition_offset 16 \
        -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot \
        -boot-load-size 4 -boot-info-table \
        -eltorito-alt-boot -e boot/efi.img -no-emul-boot \
        -isohybrid-gpt-basdat "$ISO"
    xorriso -indev "$WORK/blue-os-x86_64.iso" -report_el_torito plain | grep -q 'El Torito' || die 'Boot validation failed.'
    (cd "$WORK" && sha256sum blue-os-x86_64.iso > blue-os-x86_64.iso.sha256)
    mv -f -- "$WORK/blue-os-x86_64.iso" "$OUTPUT"
    mv -f -- "$WORK/blue-os-x86_64.iso.sha256" "$OUTPUT.sha256"
    log "Ready: $OUTPUT"
}
check_host
WORK=$(mktemp -d "$SCRIPT_DIR/.blue-os-work.XXXXXXXX")
ROOT="$WORK/rootfs" ISO="$WORK/iso"
mkdir -p "$ROOT" "$ISO"
bootstrap
install_system
configure_system
install_local_debs
package_iso
