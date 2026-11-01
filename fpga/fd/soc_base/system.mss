{
    "chip": {
        "depends": [
            "fpsoc/chip/dr1x90/common",
            "fpsoc/chip/dr1x90/dr1m90",
            "fpsoc/arch/arm",
            "fpsoc/arch/common/inc",
            "fpsoc/inc"
        ],
        "name": "dr1m90"
    },
    "doc": {
        "DOCS_DOXYGEN": {
            "name": "DOCS_DOXYGEN",
            "path": "docs/doxygen",
            "version": "1.0"
        }
    },
    "driver": {
        "PS_DRIVER_ADC": {
            "depends": [
                "fpsoc/driver/ps_driver/adc"
            ],
            "description": "",
            "name": "PS_DRIVER_ADC",
            "version": "1.0"
        },
        "PS_DRIVER_DMA": {
            "depends": [
                "fpsoc/driver/ps_driver/dma",
                "PS_DRIVER_IPC"
            ],
            "description": "",
            "name": "PS_DRIVER_DMA",
            "version": "1.0"
        },
        "PS_DRIVER_DMACAHB": {
            "depends": [
                "fpsoc/driver/ps_driver/dmacahb"
            ],
            "description": "",
            "name": "PS_DRIVER_DMACAHB",
            "version": "1.0"
        },
        "PS_DRIVER_GBE": {
            "depends": [
                "fpsoc/driver/ps_driver/gbe"
            ],
            "description": "",
            "name": "PS_DRIVER_GBE",
            "version": "1.0"
        },
        "PS_DRIVER_GPIO": {
            "depends": [
                "fpsoc/driver/ps_driver/gpio"
            ],
            "description": "",
            "name": "PS_DRIVER_GPIO",
            "version": "1.0"
        },
        "PS_DRIVER_IIC": {
            "depends": [
                "fpsoc/driver/ps_driver/iic",
                "PS_DRIVER_DMACAHB"
            ],
            "description": "",
            "name": "PS_DRIVER_IIC",
            "version": "1.0"
        },
        "PS_DRIVER_IPC": {
            "depends": [
                "fpsoc/driver/ps_driver/ipc"
            ],
            "description": "",
            "name": "PS_DRIVER_IPC",
            "version": "1.0"
        },
        "PS_DRIVER_MMC": {
            "depends": [
                "fpsoc/driver/ps_driver/mmc"
            ],
            "description": "",
            "name": "PS_DRIVER_MMC",
            "version": "1.0"
        },
        "PS_DRIVER_MPU": {
            "depends": [
                "fpsoc/driver/ps_driver/mpu"
            ],
            "description": "",
            "name": "PS_DRIVER_MPU",
            "version": "1.0"
        },
        "PS_DRIVER_PMU": {
            "depends": [
                "fpsoc/driver/ps_driver/pmu"
            ],
            "description": "",
            "name": "PS_DRIVER_PMU",
            "version": "1.0"
        },
        "PS_DRIVER_QSPI": {
            "depends": [
                "fpsoc/driver/ps_driver/qspi",
                "PS_DRIVER_DMACAHB",
                "PS_DRIVER_SPI_NOR"
            ],
            "description": "",
            "name": "PS_DRIVER_QSPI",
            "version": "1.0"
        },
        "PS_DRIVER_SMC": {
            "depends": [
                "fpsoc/driver/ps_driver/smc"
            ],
            "description": "",
            "name": "PS_DRIVER_SMC",
            "version": "1.0"
        },
        "PS_DRIVER_SPI": {
            "depends": [
                "fpsoc/driver/ps_driver/spi",
                "PS_DRIVER_DMACAHB",
                "PS_DRIVER_SPI_NOR"
            ],
            "description": "",
            "name": "PS_DRIVER_SPI",
            "version": "1.0"
        },
        "PS_DRIVER_SPI_NOR": {
            "depends": [
                "fpsoc/driver/ps_driver/spi-nor"
            ],
            "description": "",
            "name": "PS_DRIVER_SPI_NOR",
            "version": "1.0"
        },
        "PS_DRIVER_TC": {
            "depends": [
                "fpsoc/driver/ps_driver/tc"
            ],
            "description": "",
            "name": "PS_DRIVER_TC",
            "version": "1.0"
        },
        "PS_DRIVER_UART": {
            "depends": [
                "fpsoc/driver/ps_driver/uart",
                "PS_DRIVER_DMACAHB"
            ],
            "description": "",
            "name": "PS_DRIVER_UART",
            "version": "1.0"
        },
        "PS_DRIVER_USB": {
            "depends": [
                "fpsoc/driver/ps_driver/usb",
                "LIB_FATFS"
            ],
            "description": "",
            "name": "PS_DRIVER_USB",
            "version": "1.0"
        },
        "PS_DRIVER_WDT": {
            "depends": [
                "fpsoc/driver/ps_driver/wdt",
                "PS_DRIVER_PMU"
            ],
            "description": "",
            "name": "PS_DRIVER_WDT",
            "version": "1.0"
        },
        "PS_DRIVER_XMON": {
            "depends": [
                "fpsoc/driver/ps_driver/xmon"
            ],
            "description": "",
            "name": "PS_DRIVER_XMON",
            "version": "1.0"
        }
    },
    "library": {
        "LIB_FATFS": {
            "depends": [
                "3rdparty/lib/FATFS",
                "PS_DRIVER_MMC"
            ],
            "description": "Version : vR0.14b",
            "name": "LIB_FATFS",
            "version": "1.0"
        },
        "LIB_GCC": {
            "depends": [
                "fpsoc/lib/newlib/gcc"
            ],
            "description": "LIB_GCC",
            "name": "LIB_GCC",
            "version": "1.0"
        },
        "LIB_LOG": {
            "depends": [
                "fpsoc/lib/log",
                "PS_DRIVER_UART"
            ],
            "description": "LIB_LOG",
            "name": "LIB_LOG",
            "version": "1.0"
        },
        "LIB_SEMIHOST": {
            "depends": [
                "3rdparty/lib/semihost/"
            ],
            "description": "Version : 1.0",
            "name": "LIB_SEMIHOST",
            "version": "1.0"
        }
    },
    "os": {
        "depends": [],
        "description": "standalone",
        "name": "standalone",
        "version": "1.0"
    },
    "proc": {
        "name": "apu-0"
    }
}