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
  echo "Purpose: Move the boot files and devicetree to the direction and rename them."
  echo "Usage  : ${MLK_SCRIPT_NAME} [option]"
  echo "options:"
  echo "--help: Display this help message"
  exit 0;
}
expr "$*" : ".*--help" > /dev/null && usage

# => The beginning
print_info "[ $(date "+%Y/%m/%d %H:%M:%S") ] Starting ${MLK_SCRIPT_NAME}\n"

# => Make sure the target dir is there
SUBDIRECTORIES=(	\
  "kernel-dts"		\
  "uboot-dts"		\
  )

[[ ! -d "${MLK_FILES_DIR}" ]] && mkdir -p ${MLK_FILES_DIR}

for DIR in ${SUBDIRECTORIES[@]}; do
  [[ ! -d "${MLK_FILES_DIR}/${DIR}" ]] && mkdir -p ${MLK_FILES_DIR}/${DIR}
done

# => Check elf and bit
elf_files=($(find ${MLK_FILES_DIR} -maxdepth 1 -name "*.elf"))
bit_files=($(find ${MLK_FILES_DIR} -maxdepth 1 -name "*.bit"))

if [[ ${#elf_files[@]} -eq 1 && ${#bit_files[@]} -eq 1 ]]; then
    elf_basename=$(basename "${elf_files[0]}")
    bit_basename=$(basename "${bit_files[0]}")
    if [[ "$elf_basename" != "soc_fsbl.elf" ]]; then
        mv "${elf_files[0]}" "${MLK_FILES_DIR}/soc_fsbl.elf"
    fi
    if [[ "$bit_basename" != "system.bit" ]]; then
        mv "${bit_files[0]}" "${MLK_FILES_DIR}/system.bit"
    fi
else
    error_exit "Only one elf file and bit file is needed."
    exit 1
fi

# => Overview of needed files
targets=(		\
  "soc_fsbl.elf"	\
  "system.bit"		\
  )

for target in "${SUBDIRECTORIES[@]}"; do
  if [ ! -f "${MLK_FILES_DIR}/${SUBDIRECTORIES}/${MLK_DTS_NAME}" ]; then
    error_exit "Target cannot be found: ${SUBDIRECTORIES}."
  fi
done

for target in "${targets[@]}"; do
  if [ ! -f "${MLK_FILES_DIR}/${target}" ]; then
    error_exit "Target cannot be found: ${target}."
  fi
done

# => fsbl
echo_info "Move fsbl to output direction."
cp ${MLK_FILES_DIR}/soc_fsbl.elf ${MLK_OUTPUT_DIR}/fsbl.elf

# => system_wrapper
echo_info "Move system_wrapper to output direction."
cp ${MLK_FILES_DIR}/system.bit ${MLK_OUTPUT_DIR}

# => uboot-dts
echo_info "Move uboot-dts to uboot direction."
cp ${MLK_FILES_DIR}/uboot-dts/${MLK_DTS_NAME} ${MLK_UBOOT_DTS_DIR}

# => kernel-dts
echo_info "Move kernel-dts to kernel direction."
cp ${MLK_FILES_DIR}/kernel-dts/${MLK_DTS_NAME} ${MLK_KERNEL_DTS_DIR}

# => The end
print_info "[ $(date "+%Y/%m/%d %H:%M:%S") ] Finished ${MLK_SCRIPT_NAME}\n"
###############################################################################
