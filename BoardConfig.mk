# SPDX-License-Identifier: Apache-2.0
# HTC One M8 (m8whl), Qualcomm MSM8974 (Snapdragon 801, quad-core Krait 400,
# Adreno 330), 32-bit, kernel 3.4.113. Branch: twrp-14.1
# (minimal-manifest-twrp/platform_manifest_twrp_aosp), producing
# TW_MAIN_VERSION_STR 3.7.1_14 (TeamWin/android_bootable_recovery
# variables.h@android-14.1).
#
# Kernel and boot-header facts below are read from this device's own
# currently-flashed system, not assumed from the frozen TeamWin android-8.1
# tree: device/htc/msm8974-common@lineage-22.2-m8 BoardConfigCommon.mk
# (cmdline, base, pagesize, offsets, BOARD_RECOVERYIMAGE_PARTITION_SIZE) and
# a live boot_id capture of the flashed kernel's own /proc/version
# (Projects/Android/HTC/evidence/watchdog-bite-nonrepro-20260926,
# "Linux version 3.4.113-g4140df22"), which pins the exact source commit
# below. dt.img's sha256 is unchanged across every M8 kernel build sampled
# this session (the QCDT table is a static hardware description, not
# kernel-version-dependent), so the same blob this device's own
# already-flashed boot.img carries is reused here rather than repacked.

TARGET_BOARD_PLATFORM := msm8974
TARGET_BOARD_PLATFORM_GPU := qcom-adreno330
TARGET_BOOTLOADER_BOARD_NAME := MSM8974
TARGET_NO_BOOTLOADER := true
BOARD_VENDOR := htc
TARGET_OTA_ASSERT_DEVICE := m8,m8whl

TARGET_ARCH := arm
TARGET_ARCH_VARIANT := armv7-a-neon
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi
TARGET_CPU_VARIANT := krait
TARGET_CPU_SMP := true

# Kernel: Oichkatzelesfrettschen/android_kernel_htc_msm8974
# @4140df22f96e040e5dd51d196e9bd65ad784738c (branch
# kgsl-detach-recovery-ptp-interface, "usb: gadget: mtp: number the PTP
# interface descriptor at bind"), the exact commit the flashed
# lineage-22.2-20260926-UNOFFICIAL-m8 build's proc_version identifies. It
# carries the cgroup2 compat filesystem (d21c4ade876, "cgroup: Add compat
# cgroup2 fs"), FunctionFS AIO (drivers/usb/gadget/f_fs.c's
# ffs_epfile_aio_read/write, unconditional in this tree), CONFIG_BPF_SYSCALL
# and CONFIG_CGROUP_BPF (arch/arm/configs/m8_defconfig), and
# POLICYDB_VERSION_MAX 30 (security/selinux/include/security.h, no
# CONFIG_SECURITY_SELINUX_POLICYDB_VERSION_MAX_VALUE override), matching the
# policyvers 30 this device's own SELinux reports at runtime.
TARGET_PREBUILT_KERNEL := device/htc/m8/prebuilt/kernel
BOARD_KERNEL_CMDLINE := console=none androidboot.hardware=qcom user_debug=31 ehci-hcd.park=3 zcache
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 2048

# hboot 3.19's QCDT loader reads the v0 boot header's dt_size field
# (offset 40); upstream system/tools/mkbootimg dropped --dt for the
# flattened --dtb (boot header v1+), so this tree supplies its own v0
# packer instead of reworking hboot, the same design
# android_device_htc_a11chl's tools/mkbootimg_dt already proved on this
# manifest generation. HOST_OUT_EXECUTABLES is defined later in
# build/make/core/config.mk (line 686) than the point that includes this
# file, so BOARD_CUSTOM_MKBOOTIMG stays a recursively-expanded (=)
# variable; a := here would bake in an empty prefix and ninja would fail
# on a bare "/mkbootimg_dt".
BOARD_CUSTOM_MKBOOTIMG = $(HOST_OUT_EXECUTABLES)/mkbootimg_dt
BOARD_MKBOOTIMG_ARGS += \
    --kernel_offset 0x00008000 \
    --ramdisk_offset 0x02008000 \
    --second_offset 0x00f00000 \
    --tags_offset 0x01e00000 \
    --dt device/htc/m8/prebuilt/dt.img

# The dt.img above is a checked-in blob unpacked from this device's own
# flashed boot.img, not built from a dts source tree (there is none here:
# the kernel is TARGET_PREBUILT_KERNEL too), so
# vendor/twrp/build/tasks/dt_image.mk's dtbToolCM path is skipped.
BOARD_KERNEL_SEPARATED_DT := true
BOARD_KERNEL_PREBUILT_DT := true

# msm8974-common BoardConfigCommon.mk (the ROM tree this device actually
# runs): 24 MiB recovery partition, matching HARDWARE_REFERENCE_MATRIX.md
# row 162 (de768e1, msm8974-common). An oversize image fails this build
# rather than an hboot flash.
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 25165824
BOARD_BOOTIMAGE_PARTITION_SIZE := 16777216
BOARD_FLASH_BLOCK_SIZE := 131072

BOARD_USES_QCOM_HARDWARE := true
TARGET_RECOVERY_PIXEL_FORMAT := "RGBX_8888"
TARGET_RECOVERY_FSTAB := device/htc/m8/recovery.fstab
RECOVERY_SDCARD_ON_DATA := true

# TWRP UI. 1080x1920 panel (msm8974-common BoardConfigCommon.mk,
# TARGET_SCREEN_DENSITY := 480); portrait_hdpi is the theme
# TeamWin/android_device_htc_m8@android-8.1 and
# TeamWin/android_device_htc_m8_whl both already use at this density, and
# bootable_recovery@android-14.1's gui/theme carries no separate fhd
# variant to pick instead. Brightness path and max value are
# TeamWin/android_device_htc_m8_whl's own BoardConfig.mk, the real m8whl
# hardware tree.
DEVICE_RESOLUTION := 1080x1920
TW_THEME := portrait_hdpi
TW_BRIGHTNESS_PATH := /sys/class/leds/lcd-backlight/brightness
TW_MAX_BRIGHTNESS := 255
TW_NO_SCREEN_BLANK := true

TW_EXCLUDE_NANO := true
TW_EXCLUDE_BASH := true

# Scope cuts, named rather than made silently:
# - No TW_INCLUDE_CRYPTO: ro.crypto.state reads unsupported on this
#   device's flashed Android 15 build (Projects/Android/HTC/evidence/
#   build038-final-state/getprop.txt, feature-gap-audit-20260924/probes.txt)
#   and unencrypted on its earlier stock Marshmallow build
#   (blobs/device-getprop.txt); no ROM in this device's history ships
#   FDE/FBE userdata, so default-encryption unlock support is not built.
# - No AVB2 (BOARD_AVB_ENABLE): hboot 3.19 S-ON does not verify a vbmeta
#   partition (HARDWARE_REFERENCE_MATRIX.md row 1a); nothing here would be
#   checked.
# - No Treble/VINTF (BOARD_VNDK_VERSION unset): TWRP does not run the
#   HAL/VINTF-checked userspace; a recovery-only tree does not need it.
