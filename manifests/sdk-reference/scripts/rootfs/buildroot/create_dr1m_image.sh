#!/bin/bash

# => Setting The Development Environment Variables
if [ ! "${MLK_CONF_DONE}" ];then
  printf "\033[31m[ERROR]\033[0m "
  printf "Please source the configs/<BOARD NAME>.sh script first.\n"
  exit 1
fi

# => Filename of the running script
MLK_SCRIPT_NAME="$(basename ${BASH_SOURCE[0]})"

# => Directory containing the running script
MLK_SCRIPT_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"

# => Help and information
usage() {
  echo "Purpose: Building Debian/Ubuntu Image for SD card"
  echo "Usage  : ${MLK_SCRIPT_NAME} [option]"
  echo "options:"
  echo "--help: Display this help message"
  exit 0;
}
expr "$*" : ".*--help" > /dev/null && usage

# => The beginning
print_info "[ $(date "+%Y/%m/%d %H:%M:%S") ] Starting ${MLK_SCRIPT_NAME}\n"

# => Overview of needed files
targets=(                        \
  "fsbl.elf"                     \
  "system.bit"                   \
  "u-boot.bin"                   \
  "uImage.lz4"                   \
  "system.dtb"                   \
  )

for target in "${targets[@]}"; do
  if [ ! -f "${MLK_OUTPUT_DIR}/${target}" ]; then
    error_exit "Target cannot be found: ${target}."
  fi
done

# => Make sure the target dir is there
DIRECTORIES=(                    \
  "boot"                         \
  "rootfs"                       \
  )

for DIR in ${DIRECTORIES[@]}; do
  [[ ! -d "${MLK_IMAGES_DIR}/${DIR}" ]] && mkdir -p ${MLK_IMAGES_DIR}/${DIR}
done

# => make sure bootgen is there
if [ ! -f "${MLK_BOOTGEN_DIR}/linux64/bin/albg" ]; then
  error_exit "Bootgen cannot be found."
fi
BOOTGEN=${MLK_BOOTGEN_DIR}/linux64/bin/albg

# => boot.scr
CONFIGS_ARRAY=( $(cd ${MLK_BOARD_CONFIGS}/; ls parameter*.txt | sort) )
echo
echo "You're building on Linux"
echo "Lunch menu...pick a combo:"
echo ""

echo "0. default parameter-tf-fat.txt"
echo ${CONFIGS_ARRAY[@]} | xargs -n 1 | sed "=" | sed "N;s/\n/. /"

read -p "Which would you like? [0]: " INDEX
INDEX=$((${INDEX:-0} - 1))

if echo $INDEX | grep -vq [^0-9]; then
  export MLK_BOOTSCR_NAME="${CONFIGS_ARRAY[$INDEX]}"
else
  echo "Lunching for Default BoardConfig.mk boards..."
  export MLK_BOOTSCR_NAME=parameter-tf-fat.txt
fi
echo "MLK_BOOTSCR_NAME=${MLK_BOOTSCR_NAME}" > ${MLK_BOARD_CONFIGS}/.cfg

mkimage -C none -A ${ARCH} -T script -d ${MLK_BOARD_CONFIGS}/${MLK_BOOTSCR_NAME} ${MLK_OUTPUT_DIR}/boot.scr

# => BOOT.bin
echo_info "Generate the boot image for sdcard mode"
BIF_FILE=${MLK_OUTPUT_DIR}/boot.bif

# fsbl - bitstream - uboot
if [[ "${MLK_BOOTSCR_NAME}" == *"qt"* ]]; then
  echo "//arch=dr1m90; split=false; format=BIN"                                                                                                                    >  ${BIF_FILE}
  echo "the_ROM_image:"                                                                                                                                            >> ${BIF_FILE}
  echo "{"                                                                                                                                                         >> ${BIF_FILE}
  echo "    image {"                                                                                                                                               >> ${BIF_FILE}
  echo "        [bootloader,destination_cpu=apu-0,checksum=none] ${MLK_OUTPUT_DIR}/fsbl.elf"                                                                       >> ${BIF_FILE}
  echo "        [destination_device=pl,partition_owner=fsbl,encryption=none,load=0x0] ${MLK_OUTPUT_DIR}/system.bit"                                                >> ${BIF_FILE}
  echo "        [destination_device=ps,destination_cpu=apu-0,org_endian,checksum=none,load=0x0,exec=0x0,partition_owner=fsbl] ${MLK_OUTPUT_DIR}/u-boot.bin"        >> ${BIF_FILE}
  echo "    }"                                                                                                                                                     >> ${BIF_FILE}
  echo "}"                                                                                                                                                         >> ${BIF_FILE}
else
  echo "//arch=dr1m90; split=false; format=BIN"                                                                                                                    >  ${BIF_FILE}
  echo "the_ROM_image:"                                                                                                                                            >> ${BIF_FILE}
  echo "{"                                                                                                                                                         >> ${BIF_FILE}
  echo "    image {"                                                                                                                                               >> ${BIF_FILE}
  echo "        [bootloader,destination_cpu=apu-0,checksum=sha2] ${MLK_OUTPUT_DIR}/fsbl.elf"                                                                       >> ${BIF_FILE}
  echo "        [destination_device=pl,partition_owner=fsbl,encryption=none,checksum=sha2,load=0x200000] ${MLK_OUTPUT_DIR}/system.bit"                             >> ${BIF_FILE}
  echo "        [destination_device=ps,destination_cpu=apu-0,org_endian,checksum=sha2,load=0x200000,exec=0x200000,partition_owner=fsbl] ${MLK_OUTPUT_DIR}/u-boot.bin" >> ${BIF_FILE}
  echo "    }"                                                                                                                                                     >> ${BIF_FILE}
  echo "}"                                                                                                                                                         >> ${BIF_FILE}
fi

${BOOTGEN} -w -log info -image ${BIF_FILE} -arch dr1m90 -o ${MLK_OUTPUT_DIR}/BOOT.bin

# => BOOT.bin
echo_info "BOOT.bin"
cp ${MLK_OUTPUT_DIR}/BOOT.bin ${MLK_IMAGES_DIR}/boot/BOOT.bin

# => boot.scr
echo_info "boot.scr"
cp ${MLK_OUTPUT_DIR}/boot.scr ${MLK_IMAGES_DIR}/boot/boot.scr

# => uImage
echo_info "Linux kernel with modified header for U-Boot"
cp ${MLK_OUTPUT_DIR}/uImage.lz4 ${MLK_IMAGES_DIR}/boot/uImage.lz4

# => devicetree.dtb
echo_info "Device tree blob"
cp ${MLK_OUTPUT_DIR}/system.dtb ${MLK_IMAGES_DIR}/boot/system.dtb

# => uInitrd.lz4
if [[ "${MLK_BOOTSCR_NAME}" != *"ext4"* ]]; then
  if [ ! -f "${MLK_OUTPUT_DIR}/uInitrd.lz4" ]; then
    error_exit "Target cannot be found: uInitrd.lz4."
  else
    echo_info "Generate the ${MLK_ROOTFS_TYPE} Root filesystem"
    cp ${MLK_OUTPUT_DIR}/uInitrd.lz4 ${MLK_IMAGES_DIR}/boot/uInitrd.lz4
  fi
else
  if [ -f "${MLK_IMAGES_DIR}/boot/uInitrd.lz4" ]; then
    rm ${MLK_IMAGES_DIR}/boot/uInitrd.lz4
  fi
  cp ${MLK_OUTPUT_DIR}/rootfs.tar.gz ${MLK_IMAGES_DIR}/rootfs/rootfs.tar.gz
fi

# => The end
print_info "[ $(date "+%Y/%m/%d %H:%M:%S") ] Finished ${MLK_SCRIPT_NAME}\n"
