# SPDX-License-Identifier: Apache-2.0
# HTC One M8 (m8whl), Qualcomm MSM8974 (Snapdragon 801, quad-core Krait 400,
# Adreno 330), 32-bit, kernel 3.4.113. Branch: twrp-14.1
# (minimal-manifest-twrp/platform_manifest_twrp_aosp), producing
# TW_MAIN_VERSION_STR 3.7.1_14 (TeamWin/android_bootable_recovery
# variables.h@android-14.1).
#
# The recovery kernel provenance and boot-header facts use separate inputs.
# The kernel comes from the merged Clang ThinLTO build documented below.
# Header facts come from the M8 boot.img pairing build 387's ramdisk, cmdline
# and dt.img with kernel 0cd1d1eb235f (sha256
# 090e1a4d3f69f0f9cdae74c257c4be3dc2f76649b97d653243f682f963165f6d; build
# 387's own boot.img, 2570b386, differs only in the kernel) and are read with
# unpackbootimg. The frozen TeamWin android-8.1 tree and
# device/htc/msm8974-common's declared BoardConfigCommon.mk do not establish
# the final header values; that common file's BOARD_KERNEL_CMDLINE additions
# do not all survive into the final image (see BOARD_KERNEL_CMDLINE below).

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

# prebuilt/kernel and prebuilt/dt.img are the recovery kernel and QCDT
# table. The kernel build has no device-tree source delta from v18, so the
# existing build-387 dt.img remains its byte-identical match. prebuilt/kernel
# (sha256 eac30b65385dfd2e2274cc8def4a6fbc496a99ce1ab48081a52a985df246189f)
# reports "Linux version 3.4.113-g9d2468e726c5 ... clang version 22.0.0 ...
# #1 SMP PREEMPT Sun Oct 4 19:45:57 PDT 2026", built from
# Oichkatzelesfrettschen/android_kernel_htc_msm8974@9d2468e726c5e78c774f47dee8176d25323c2c7e
# with build 387's release-candidate .config, Clang r584948 ThinLTO, and
# -Werror. Its cgroup_bpf_inherit() returns compute_effective_progs()'s error,
# including -EBUSY, instead of replacing it with -ENOMEM. The binary ships
# instead of a local rebuild because a kernel build is not byte-reproducible
# across build environments. The kernel carries the compat cgroup2 filesystem
# (kernel/cgroup.c compat_cgroup2_fs_type), so
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
# The flashed image's own header carries no androidboot.selinux token
# (see above), but recovery's own cmdline is not required to match the
# ROM's boot.img byte for byte, and TWRP needs the token restored: the
# ROM's own sepolicy labels the android_usb sysfs nodes
# usb_function_switch writes to, while TWRP's recovery policy carries
# none of those labels, so an enforcing recovery would deny the write
# and adb -- the only log channel a RAM-boot test has -- would never
# bind. The pinned kernel's own embedded ikconfig carries
# CONFIG_SECURITY_SELINUX_DEVELOP=y, so the kernel honors the token, and
# TeamWin's own android-8.1 tree (the one that produced the official,
# booting twrp-3.7.0_9-0-m8.img) carries the same token in its recovery
# cmdline.
BOARD_KERNEL_CMDLINE := console=none androidboot.hardware=qcom user_debug=31 ehci-hcd.park=3 zcache loop.max_part=7
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive
# hboot 3.19 boots the recovery partition with androidboot.mode=offmode_charging
# for power-off charging (USB inserted while the phone is off) and for its
# RECOVERY menu entry after a USB-insertion power-on, and appends that token
# after this cmdline, so recovery cannot override it. htc.recovery_boot=1
# makes arch/arm/mach-msm/devices_cmdline.c report MFG_MODE_RECOVERY for that
# boot, so board_mfg_mode()'s off-mode checks leave the synaptics touch
# controller and the CwMcu sensor hub probed.
BOARD_KERNEL_CMDLINE += htc.recovery_boot=1
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

# bootable/recovery's own twrp_ramdisk module omits task_profiles.json
# from its LOCAL_REQUIRED_MODULES despite copying it in the same recipe
# (every other file that recipe copies is listed there); the fix lives in
# the pinned bootable/recovery fork
# (Oichkatzelesfrettschen/android_bootable_recovery-m8-twrp,
# m8-task-profiles-fix), not here -- no BoardConfig variable orders a
# BUILD_PHONY_PACKAGE's own post-install recipe against another module.

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
