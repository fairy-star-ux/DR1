#!/bin/bash
# Run configure_sdk.py first. Compile everything against the same kernel tree.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
SDK=${1:?Usage: build_linux.sh /absolute/path/to/uisrc-lab-anlogic}
SDK=$(cd "$SDK" && pwd)
JOBS=${JOBS:-16}
KERNEL="$SDK/sources/linux"
OVERLAY="$SDK/boards/DR1M/boat-overlay"
OUT="$REPO/artifacts/rebuilt"
CROSS_COMPILE=${CROSS_COMPILE:-"$SDK/tools/aarch64-linux/bin/aarch64-linux-gnu-"}
FIRMWARE_DIR=${FIRMWARE_DIR:-"$REPO/artifacts/runtime-deps/lib/firmware/aic8800D80"}
test -f "$KERNEL/.config" -a -f "$OVERLAY/usr/local/bin/boat_web_server.py"
test -f "$FIRMWARE_DIR/fw_patch_table_8800d80_u02.bin"
command -v mkimage >/dev/null
command -v lz4 >/dev/null
command -v depmod >/dev/null
mkdir -p "$OUT"
export ARCH=arm64 CROSS_COMPILE
make -C "$KERNEL" olddefconfig
make -C "$KERNEL" -j"$JOBS" Image modules dtbs
RELEASE=$(make -s -C "$KERNEL" kernelrelease)
test "$RELEASE" = 6.1.111-rt42 || { echo "Unexpected kernel release: $RELEASE"; exit 1; }
make -C "$KERNEL" modules_install INSTALL_MOD_PATH="$OVERLAY" INSTALL_MOD_STRIP=1
# Build from a writable copy so source and clean Git state stay intact.
DRIVER="$OUT/aic8800-build"
mkdir -p "$DRIVER"
cp -a "$REPO/linux/drivers/aic8800/." "$DRIVER/"
make -C "$KERNEL" -j"$JOBS" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" M="$DRIVER" modules
mkdir -p "$OVERLAY/lib/modules/$RELEASE/extra" "$OVERLAY/lib/firmware/aic8800D80"
install -m644 "$DRIVER/aic_load_fw/aic_load_fw.ko" "$OVERLAY/lib/modules/$RELEASE/extra/"
install -m644 "$DRIVER/aic8800_fdrv/aic8800_fdrv.ko" "$OVERLAY/lib/modules/$RELEASE/extra/"
cp -a "$FIRMWARE_DIR/." "$OVERLAY/lib/firmware/aic8800D80/"
depmod -b "$OVERLAY" "$RELEASE"
make -C "$REPO/linux" CC="${CROSS_COMPILE}gcc" BUILD="$OUT/tools" -j"$JOBS"
install -m755 "$OUT/tools/camera_capture" "$OVERLAY/usr/local/bin/"
lz4 -f -9 "$KERNEL/arch/arm64/boot/Image" "$OUT/Image.lz4"
mkimage -A arm64 -O linux -T kernel -C lz4 -a 0x00400000 -e 0x00400000 -n Linux -d "$OUT/Image.lz4" "$OUT/uImage.lz4"
cp "$KERNEL/arch/arm64/boot/dts/anlogic/anlogic-dr1.dtb" "$OUT/system.dtb"
BR="$SDK/sources/buildroot"
make -C "$BR" olddefconfig
make -C "$BR" BR2_JLEVEL="$JOBS" -j"$JOBS"
cp "$BR/output/images/rootfs.tar.gz" "$OUT/rootfs.tar.gz"
python3 "$REPO/scripts/verify_rootfs.py" "$OUT/rootfs.tar.gz" --match-repo
sha256sum "$OUT/uImage.lz4" "$OUT/system.dtb" "$OUT/rootfs.tar.gz" >"$OUT/linux.sha256"
echo "Linux build complete: $OUT; no SD card was modified."
