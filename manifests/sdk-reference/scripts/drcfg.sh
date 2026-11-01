#!/bin/bash

# => Force locale language to be set to English. This avoids issues when doing
# text and string processing.
export LC_ALL=C LANGUAGE=C LANG=C

# => The root filesystem (buildroot)
MLK_ROOTFS_TYPE="buildroot"
# => Board family (DR1M\DR1V)
MLK_BOARD_FAMILY="DR1M"

# => Filename of the running script
MLK_SCRIPT_NAME="$(basename ${BASH_SOURCE[0]})"

# => Directory containing the running script
MLK_SCRIPT_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"

# => Help and information
usage() {
  echo "Purpose: To configure the developing environment automatically"
  echo "Usage : source ${MLK_SCRIPT_NAME}"
  exit 0;
}
expr "$*" : ".*--help" > /dev/null && usage

# => Import local function from common.sh
if [ -f "${MLK_SCRIPT_DIR}/common.sh" ]; then
  source ${MLK_SCRIPT_DIR}/common.sh
else
  printf "\033[31m[ERROR]\033[0m "
  printf "Could not find file '${MLK_SCRIPT_DIR}/common.sh'\n"
  exit 1
fi

# => Make sure the script is being source'd, not executed.
# Otherwise, environment variables set here will not stick.
if [ ${BASH_SOURCE[0]} == "$0" ]; then
  error_exit "Please execute the script, such as: source ${MLK_SCRIPT_NAME}"
fi

# => Only use sudo if not running as root:
[ "$(id -u)" -ne 0 ] && export SUDO="sudo" || export SUDO=""

#------------------------------------------------------------------------------
# The basic directory
#------------------------------------------------------------------------------
# => The Top Directory
export MLK_TOP_DIR="$(dirname $MLK_SCRIPT_DIR)"
export MLK_TOP_NAME="$(basename $MLK_TOP_DIR)"

# => The Boards Directory
export MLK_BOARDS_DIR="${MLK_TOP_DIR}/boards"

# => The Packages Directory
export MLK_DOWNLOADS_DIR="${MLK_TOP_DIR}/packages"

# => The Scripts Directory
export MLK_SCRIPTS_DIR="${MLK_TOP_DIR}/scripts"

# => The Sources Directory
export MLK_SOURCES_DIR="${MLK_TOP_DIR}/sources"

# => The Tools Directory
export MLK_TOOLS_DIR="${MLK_TOP_DIR}/tools"

# => Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
mkdir -p ${MLK_BOARDS_DIR} ${MLK_DOWNLOADS_DIR} ${MLK_SCRIPTS_DIR} ${MLK_SOURCES_DIR} ${MLK_TOOLS_DIR}

#------------------------------------------------------------------------------
# The Boards directory
#------------------------------------------------------------------------------
# => The Board Name (maker_board_lab)
export MLK_BOARD_NAME="${MLK_BOARD_FAMILY}/${MLK_ROOTFS_TYPE}"

# => The Board Directory
export MLK_BOARD_DIR="${MLK_BOARDS_DIR}/${MLK_BOARD_NAME}"

# => The Board Configs
export MLK_BOARD_CONFIGS="${MLK_BOARDS_DIR}/${MLK_BOARD_FAMILY}/configs"

# => The Sources Configs
export MLK_SOURCES_CONFIGS="${MLK_BOARD_CONFIGS}/defconfigs"

# => The Input Directory
export MLK_FILES_DIR="${MLK_BOARDS_DIR}/files"

# => The Images Directory
export MLK_IMAGES_DIR="${MLK_BOARD_DIR}/images"

# => The Output Directory
export MLK_OUTPUT_DIR="${MLK_BOARD_DIR}/output"

# => Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
mkdir -p ${MLK_BOARD_DIR} ${MLK_BOARD_CONFIGS} ${MLK_SOURCES_CONFIGS} ${MLK_FILES_DIR} ${MLK_IMAGES_DIR} ${MLK_OUTPUT_DIR}

#------------------------------------------------------------------------------
# Describe the toolchain for developing an embedded Linux operating system
#------------------------------------------------------------------------------
# => Select CPU types (arm64/rsicv) based on family
case "$MLK_BOARD_FAMILY" in
  "DR1M")
    export ARCH="arm64"
    ;;
  "DR1V")
    export ARCH="riscv"
    ;;
  *)
    echo "Unknown board family: $MLK_BOARD_FAMILY"
    exit 1
    ;;
esac

# => Select a cross-compiler based on ARCH
if [ "$ARCH" = "arm64" ]; then
    export MLK_TOOLCHAIN_DIR="${MLK_TOOLS_DIR}/aarch64-linux/bin"
    export MLK_TOOLCHAIN_PREFIX="${MLK_TOOLCHAIN_DIR}/aarch64-linux-gnu"
    export CROSS_COMPILE="${MLK_TOOLCHAIN_PREFIX}-"
    if which ${CROSS_COMPILE} > /dev/null 2>&1 ; then
        echo "Could not find the aarch64 cross compiler" && return 1
    fi
elif [ "$ARCH" = "riscv" ]; then
    export MLK_TOOLCHAIN_DIR="${MLK_TOOLS_DIR}/riscv64-linux/bin"
    export MLK_TOOLCHAIN_PREFIX="${MLK_TOOLCHAIN_DIR}/riscv64-unknown-linux-gnu"
    export CROSS_COMPILE="${MLK_TOOLCHAIN_PREFIX}-"
    if which ${CROSS_COMPILE} > /dev/null 2>&1 ; then
        echo "Could not find the riscv cross compiler" && return 1
    fi
else
    echo "Unsupported architecture: $ARCH" && return 1
fi

# => Scale the maximum concurrency with the number of CPUs.
export MLK_MAKE_JOBS="-j$(nproc)"

#------------------------------------------------------------------------------
# System Software Development
#------------------------------------------------------------------------------
# => Bootgen
export MLK_BOOTGEN_DIR="${MLK_TOOLS_DIR}/bootgen"

# => Build U-Boot
# ==> this folder stores opensbi code.
export MLK_OPENSBI_DIR="${MLK_SOURCES_DIR}/opensbi"

# ==> ssbl : this folder stores all the U-Boot code.
export MLK_UBOOT_DIR="${MLK_SOURCES_DIR}/u-boot"

# ==> Configure the bootloader for the Zynq target
export MLK_UBOOOT_DEFCONFIG=anlogic_dr1_uboot_defconfig

# ==> Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
mkdir -p ${MLK_UBOOT_DIR}

# => Build Linux
# ==> kernel : this folder stores the object files (not sources) of the kernel
# build process.
export MLK_KERNEL_DIR="${MLK_SOURCES_DIR}/linux"
export MLK_KERNEL_IMG="${MLK_KERNEL_DIR}/arch/${ARCH}/boot/Image"
export MLK_KERNEL_lz4_IMG="${MLK_KERNEL_DIR}/arch/${ARCH}/boot/Image.lz4"
export MLK_KERNEL_lz4_UIMG="${MLK_KERNEL_DIR}/arch/${ARCH}/boot/uImage.lz4"

# ==> Configure the Linux Kernel for the Zynq target
export MLK_KERNEL_DEFCONFIG=anlogic_dr1_kernel_defconfig

# ==> Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
mkdir -p ${MLK_KERNEL_DIR}

# => Device Tree
# ==> DTC (Device Tree Compiler)
export MLK_DTC_DIR="${MLK_KERNEL_DIR}/scripts/dtc"
export PATH="${MLK_DTC_DIR}":${PATH}

# ==> DTS (Device Tree Source)
export MLK_DTS_NAME="anlogic-dr1.dts"
export MLK_UBOOT_DTS_DIR="${MLK_UBOOT_DIR}/arch/${ARCH/arm64/arm}/dts"
export MLK_KERNEL_DTS_DIR="${MLK_KERNEL_DIR}/arch/${ARCH}/boot/dts/anlogic"

# ==> DTB (Device Tree Blob)
export MLK_DTB_NAME="anlogic-dr1.dtb"
export MLK_DTB_DIR="${MLK_KERNEL_DIR}/arch/${ARCH}/boot/dts/anlogic"

# ==> Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
mkdir -p ${MLK_UBOOT_DTS_DIR} ${MLK_KERNEL_DTS_DIR}

# => The root filesystem (buildroot)
export MLK_ROOTFS_DIR="${MLK_SOURCES_DIR}/rootfs/${MLK_ROOTFS_TYPE}"

# => The buildroot direction
export MLK_BUILDROOT_DIR="${MLK_SOURCES_DIR}/buildroot"

if [ ${MLK_ROOTFS_TYPE} == "ramdisk" ] || [ ${MLK_ROOTFS_TYPE} == "buildroot" ]; then
  # ==> Configure the buildroot for the target
  export MLK_BUILDROOT_DEFCONFIG=anlogic_dr1_buildroot_defconfig

  # => Ramdisk Constants
  export MLK_BLOCK_SIZE=1024
  export MLK_RAMDISK_SIZE="$((64 * 1024))" # 64MB
fi

# ==> Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
mkdir -p ${MLK_ROOTFS_DIR} ${MLK_ROOTFS_DIR}

#------------------------------------------------------------------------------
# Adding the Directory to the Path
#------------------------------------------------------------------------------
export PATH="${MLK_SCRIPTS_DIR}":$PATH

for dir in $( ls ${MLK_SCRIPTS_DIR}/ ); do
  if [ -d "${MLK_SCRIPTS_DIR}/${dir}" ]; then
    export PATH="${MLK_SCRIPTS_DIR}/${dir}":$PATH
  fi
done

if [ -d "${MLK_SCRIPTS_DIR}/rootfs/${MLK_ROOTFS_TYPE}" ]; then
  export PATH="${MLK_SCRIPTS_DIR}/rootfs/${MLK_ROOTFS_TYPE}":$PATH
fi

#------------------------------------------------------------------------------
# => The end
#------------------------------------------------------------------------------
export MLK_CONF_DONE="done"
