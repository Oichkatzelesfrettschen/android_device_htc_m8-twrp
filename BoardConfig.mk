# SPDX-License-Identifier: Apache-2.0
# HTC One M8 (m8whl), Qualcomm MSM8974 (Snapdragon 801, quad-core Krait 400,
# Adreno 330), 32-bit, kernel 3.4.113. Branch: twrp-14.1
# (minimal-manifest-twrp/platform_manifest_twrp_aosp), producing
# TW_MAIN_VERSION_STR 3.7.1_14 (TeamWin/android_bootable_recovery
# variables.h@android-14.1).
#
# Kernel and boot-header facts below are read directly from the
# currently-flashed build's own boot.img (lineage-22.2-20260926-UNOFFICIAL-m8.zip,
# sha256 f7437c450d47ba902caf4aa7008b2ee6627df14e1220db483af48a52f59aca99,
# HARDWARE_REFERENCE_MATRIX.md row 16/276) with unpackbootimg, not assumed
# from the frozen TeamWin android-8.1 tree or from device/htc/msm8974-common's
# declared BoardConfigCommon.mk, whose BOARD_KERNEL_CMDLINE additions do not
# all survive into the final image (see BOARD_KERNEL_CMDLINE below).

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

# prebuilt/kernel is build076's own flashed kernel binary (sha256
# 316967b3a3ad181cb11ffd3b111e176f3f42ceeaca25811eda7dd66bd6a90c1f, its
# LZMA-compressed payload decompresses to a Linux version banner and an
# embedded ikconfig identical to the source pin below), not a local
# rebuild: a kernel build is not byte-reproducible across build
# environments, and the RAM-boot test should not carry that variable
# alongside the device tree itself. The pin is
# Oichkatzelesfrettschen/android_kernel_htc_msm8974
# @4140df22f96e040e5dd51d196e9bd65ad784738c (branch
# kgsl-detach-recovery-ptp-interface, "usb: gadget: mtp: number the PTP
# interface descriptor at bind"), the exact commit the flashed build's own
# proc_version identifies; its embedded ikconfig matches an m8_defconfig
# build with the LineageOS 18.1 GCC 4.9.x (20150123) prebuilt cross
# toolchain byte-for-byte. The commit carries the cgroup2 compat
# filesystem (d21c4ade876, "cgroup: Add compat cgroup2 fs"), so
# createProcessGroup() succeeds through the ordinary mount path on
# twrp-14.1's fatal-on-failure init (see README.md, "Verified
# non-issues"). Its USB gadget is drivers/usb/gadget/android.c's composite
# driver, which #includes f_fs.c directly (FunctionFS is compiled into
# that composite driver regardless of the standalone CONFIG_USB_FUNCTIONFS
# Kconfig option, which this defconfig leaves unset); recovery/root's
# init.recovery.qcom.rc carries the three adbd-over-FFS properties this
# kernel's gadget needs. POLICYDB_VERSION_MAX resolves to 30
# (security/selinux/include/security.h, no
# CONFIG_SECURITY_SELINUX_POLICYDB_VERSION_MAX_VALUE override), matching
# the policyvers 30 this device's own SELinux reports at runtime.
TARGET_PREBUILT_KERNEL := device/htc/m8/prebuilt/kernel
BOARD_KERNEL_CMDLINE := console=none androidboot.hardware=qcom user_debug=31 ehci-hcd.park=3 zcache loop.max_part=7
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 2048

# hboot 3.19's QCDT loader reads the v0 boot header's dt_size field
# (offset 40); upstream system/tools/mkbootimg dropped --dt for the
# flattened --dtb (boot header v1+), so this tree supplies its own v0
# packer instead of reworking hboot, the same design
# android_device_htc_a11chl's tools/mkbootimg_dt already proved on this
# manifest generation. HOST_OUT_EXECUTABLES is defined later in
# build/make/core/config.mk than the point that includes this file, so
# BOARD_CUSTOM_MKBOOTIMG stays a recursively-expanded (=) variable; a :=
# here would bake in an empty prefix and ninja would fail on a bare
# "/mkbootimg_dt".
BOARD_CUSTOM_MKBOOTIMG = $(HOST_OUT_EXECUTABLES)/mkbootimg_dt
BOARD_MKBOOTIMG_ARGS += \
    --kernel_offset 0x00008000 \
    --ramdisk_offset 0x02008000 \
    --second_offset 0x00000000 \
    --tags_offset 0x01e00000

# build/make/core/Makefile sets INSTALLED_DTIMAGE_TARGET :=
# $(PRODUCT_OUT)/dt.img and makes it a hard ninja prerequisite of both
# boot.img and recovery.img whenever BOARD_KERNEL_SEPARATED_DT is true,
# appending its own "--dt $(INSTALLED_DTIMAGE_TARGET)" to
# INTERNAL_RECOVERYIMAGE_ARGS -- unconditionally on BOARD_KERNEL_PREBUILT_DT,
# unlike vendor/twrp/build/tasks/dt_image.mk's own dtbToolCM rule, which
# that flag does gate. twrp_m8.mk's PRODUCT_COPY_FILES entry gives
# $(PRODUCT_OUT)/dt.img a producer (a plain copy of the checked-in blob
# below), so BOARD_MKBOOTIMG_ARGS carries no "--dt" of its own here -- the
# Makefile's own unconditional flag already names the right file.
BOARD_KERNEL_SEPARATED_DT := true
BOARD_KERNEL_PREBUILT_DT := true

# msm8974-common BoardConfigCommon.mk (the ROM tree this device actually
# runs): 24 MiB recovery partition, matching HARDWARE_REFERENCE_MATRIX.md
# row 162 (de768e1, msm8974-common). An oversize image fails this build
# rather than an hboot flash. The ramdisk is xz for the same reason that
# tree's own comment gives: a gzip recovery ramdisk pushes recovery.img
# above this partition's budget.
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 25165824
BOARD_BOOTIMAGE_PARTITION_SIZE := 16777216
BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_RAMDISK_USE_XZ := true
XZ := prebuilts/build-tools/$(HOST_PREBUILT_TAG)/bin/xz

BOARD_USES_QCOM_HARDWARE := true
TARGET_RECOVERY_FSTAB := device/htc/m8/recovery.fstab
RECOVERY_SDCARD_ON_DATA := true

# bootable/recovery/Android.mk's own twrp_ramdisk-timestamp recipe relinks
# system/etc/task_profiles.json into the ramdisk (libprocessgroup reads
# it) with a plain shell cp and no ninja edge that builds the file first;
# `make recoveryimage` never processes PRODUCT_PACKAGES (that drives
# system.img, a target this build never runs), so a PRODUCT_PACKAGES
# entry is not a producer here. TARGET_RECOVERY_DEVICE_MODULES is: it
# feeds TWRP_REQUIRED_MODULES the same way plat_service_contexts and
# hwservicemanager already do (Android.mk lines 545-551), which is why
# those two build successfully with no device-tree entry of their own.
TARGET_RECOVERY_DEVICE_MODULES += task_profiles.json

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

# device/htc/msm8974-common's own ROM-side init.qcom.usb.rc writes
# usb_function_switch (drivers/usb/gadget/htc_attr.c's own bitmask store)
# on every function transition, alongside the base android_usb
# functions/enable pair; bootable_recovery's generic default rc writes
# only the base pair. TeamWin's own recovery/root/init.recovery.usb.rc,
# the file that shipped in the official twrp-3.7.0_9-0-m8.img, already
# carries both, so it replaces the default here rather than patching it.
TW_EXCLUDE_DEFAULT_USB_INIT := true

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
