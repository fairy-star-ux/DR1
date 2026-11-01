#!/bin/bash
# Update two already-mounted SD partitions; intentionally never partitions/formats disks.
set -euo pipefail
BOOT=${1:?Usage: install_sd.sh BOOT_MOUNT ROOTFS_MOUNT IMAGE_DIR --install}
ROOT=${2:?}
IMAGES=${3:?}
test "${4:-}" = --install || { echo 'Explicit --install is required'; exit 1; }
BOOT=$(realpath "$BOOT"); ROOT=$(realpath "$ROOT"); IMAGES=$(realpath "$IMAGES")
test "$BOOT" != / -a "$ROOT" != / -a "$BOOT" != "$ROOT"
mountpoint -q "$BOOT"; mountpoint -q "$ROOT"
findmnt -n -o SOURCE,FSTYPE --target "$BOOT"
findmnt -n -o SOURCE,FSTYPE --target "$ROOT"
test "$(findmnt -n -o FSTYPE --target "$BOOT")" = vfat
test "$(findmnt -n -o FSTYPE --target "$ROOT")" = ext4
BOOTDEV=$(findmnt -n -o SOURCE --target "$BOOT")
ROOTDEV=$(findmnt -n -o SOURCE --target "$ROOT")
HOSTDEV=$(findmnt -n -o SOURCE --target /)
test -b "$BOOTDEV" -a -b "$ROOTDEV"
BOOTDISK=$(lsblk -n -o PKNAME "$BOOTDEV")
ROOTDISK=$(lsblk -n -o PKNAME "$ROOTDEV")
test -n "$BOOTDISK" -a "$BOOTDISK" = "$ROOTDISK" || { echo 'Two partitions must belong to the same SD disk'; exit 1; }
if lsblk -s -n -o NAME "$HOSTDEV" 2>/dev/null | grep -Fxq "$ROOTDISK"; then
    echo 'Refusing to overwrite a partition on the host root disk'; exit 1
fi
echo 'Verify these are the intended SD FAT and ext4 partitions. Existing rootfs files are preserved/overlaid.'
for f in BOOT.bin boot.scr uImage.lz4 system.dtb rootfs.tar.gz; do test -s "$IMAGES/$f"; done
REPO=$(cd "$(dirname "$0")/.." && pwd)
python3 "$REPO/scripts/verify_rootfs.py" "$IMAGES/rootfs.tar.gz"
BACKUP="$IMAGES/sd-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP/boot"
sudo cp -a "$BOOT/." "$BACKUP/boot/"
sudo tar --numeric-owner -czpf "$BACKUP/rootfs.tar.gz" -C "$ROOT" .
gzip -t "$BACKUP/rootfs.tar.gz"
sudo tar --numeric-owner -xzpf "$IMAGES/rootfs.tar.gz" -C "$ROOT"
for f in BOOT.bin boot.scr uImage.lz4 system.dtb; do
    sudo cp "$IMAGES/$f" "$BOOT/$f.new"
    sudo cmp "$IMAGES/$f" "$BOOT/$f.new"
    sudo mv "$BOOT/$f.new" "$BOOT/$f"
done
sync
sha256sum "$BOOT/BOOT.bin" "$BOOT/uImage.lz4" "$BOOT/system.dtb"
echo "Installed; rollback backup: $BACKUP. Unmount both SD partitions before removal."
