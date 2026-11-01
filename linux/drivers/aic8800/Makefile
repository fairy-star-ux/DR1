CONFIG_AIC_LOADFW_SUPPORT := y
CONFIG_AIC8800_WLAN_SUPPORT := y

obj-$(CONFIG_AIC_LOADFW_SUPPORT)    += aic_load_fw/
obj-$(CONFIG_AIC8800_WLAN_SUPPORT) += aic8800_fdrv/

########## config option ##########
export CONFIG_USE_FW_REQUEST = n
export CONFIG_PREALLOC_RX_SKB = y
export CONFIG_PREALLOC_TXQ = y
###################################

########## platform support list ##########
export CONFIG_PLATFORM_ROCKCHIP = y
export CONFIG_PLATFORM_ALLWINNER = n
export CONFIG_PLATFORM_AMLOGIC = n
export CONFIG_PLATFORM_HI = n
export CONFIG_PLATFORM_UBUNTU = n

ifeq ($(CONFIG_PLATFORM_ROCKCHIP), y)
ARCH = arm64
#KDIR = /home/uisrc/rk3588/kernel
#CROSS_COMPILE = /opt/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
KDIR = /home/user/project/project/milianke/kernel-6.1
CROSS_COMPILE = /home/user/project/project/milianke/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu- 
ccflags-y += -DANDROID_PLATFORM
endif

ifeq ($(CONFIG_PLATFORM_ALLWINNER), y)
KDIR  = /home/uisrc/rk3588/kernel
ARCH = arm64
CROSS_COMPILE = /opt/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
ccflags-y += -DANDROID_PLATFORM
endif

ifeq ($(CONFIG_PLATFORM_AMLOGIC), y)
ccflags-y += -DANDROID_PLATFORM
ARCH = arm
CROSS_COMPILE = /opt/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
KDIR = /home/uisrc/rk3588/kernel
endif

ifeq ($(CONFIG_PLATFORM_HI), y)
ccflags-y += -DANDROID_PLATFORM
ARCH = arm
CROSS_COMPILE = /opt/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
KDIR = /home/uisrc/rk3588/kernel
endif

ifeq ($(CONFIG_PLATFORM_UBUNTU), y)
KDIR  = /lib/modules/$(shell uname -r)/build
PWD   = $(shell pwd)
KVER = $(shell uname -r)
MODDESTDIR = /lib/modules/$(KVER)/kernel/drivers/net/wireless/aic8800
SUBARCH = $(shell uname -m | sed -e s/i.86/i386/ -e s/armv.l/arm/ -e s/aarch64/arm64/)
ARCH ?= $(SUBARCH)
CROSS_COMPILE ?=
endif

###########################################

MAKEFLAGS +=-j$(shell nproc)

all: modules
modules:
	make -C $(KDIR) M=$(PWD) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) modules

install:
	mkdir -p $(MODDESTDIR)
	install -p -m 644 aic_load_fw/aic_load_fw.ko  $(MODDESTDIR)/
	install -p -m 644 aic8800_fdrv/aic8800_fdrv.ko  $(MODDESTDIR)/
	/sbin/depmod -a ${KVER}

uninstall:
	rm -rfv $(MODDESTDIR)/aic_load_fw.ko
	rm -rfv $(MODDESTDIR)/aic8800_fdrv.ko
	/sbin/depmod -a ${KVER}

clean:
	cd aic_load_fw/;make clean;cd ..
	cd aic8800_fdrv/;make clean;cd ..
	rm -rf modules.order Module.symvers .modules.order.cmd .Module.symvers.cmd .tmp_versions/
