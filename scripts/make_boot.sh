#!/bin/bash
# Official FSBL -> PL -> U-Boot boot image; does not write SD or Flash.
set -euo pipefail
SDK=${1:?Usage: make_boot.sh SDK FSBL_ELF SYSTEM_BIT UBOOT_BIN OUTPUT_DIR}
FSBL=$(realpath "${2:?}")
BIT=$(realpath "${3:?}")
UBOOT=$(realpath "${4:?}")
mkdir -p "${5:?}"
OUT=$(realpath "$5")
SDK=$(realpath "$SDK")
for file in "$FSBL" "$BIT" "$UBOOT"; do test -s "$file"; done
cat >"$OUT/boot.bif" <<EOF
//arch=dr1m90; split=false; format=BIN
the_ROM_image:
{
    image {
        [bootloader,destination_cpu=apu-0,checksum=sha2] $FSBL
        [destination_device=pl,partition_owner=fsbl,encryption=none,checksum=sha2,load=0x200000] $BIT
        [destination_device=ps,destination_cpu=apu-0,org_endian,checksum=sha2,load=0x200000,exec=0x200000,partition_owner=fsbl] $UBOOT
    }
}
EOF
"$SDK/tools/bootgen/linux64/bin/albg" -w -log info -image "$OUT/boot.bif" -arch dr1m90 -o "$OUT/BOOT.bin"
REPO=$(cd "$(dirname "$0")/.." && pwd)
mkimage -C none -A arm64 -T script -d "$REPO/linux/boot/boot.cmd" "$OUT/boot.scr"
sha256sum "$FSBL" "$BIT" "$UBOOT" "$OUT/BOOT.bin" "$OUT/boot.scr" >"$OUT/boot-inputs.sha256"
echo "BOOT.bin generated; original SDK/kernel/rootfs untouched."
