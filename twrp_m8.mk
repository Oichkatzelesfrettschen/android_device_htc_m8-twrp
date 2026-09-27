# SPDX-License-Identifier: Apache-2.0
# Base product graph, matching Oichkatzelesfrettschen/android_device_htc_a11chl
# (twrp-11, twrp_a11chl.mk): full_base_telephony.mk plus vendor/twrp's own
# config, minus core_64_bit.mk. This device is 32-bit only, TARGET_ARCH := arm.
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)
$(call inherit-product, vendor/twrp/config/common.mk)

# Gives $(PRODUCT_OUT)/dt.img a producer: build/make/core/Makefile makes
# it a hard prerequisite of recovery.img whenever BOARD_KERNEL_SEPARATED_DT
# is true, unconditionally on BOARD_KERNEL_PREBUILT_DT (BoardConfig.mk).
PRODUCT_COPY_FILES += device/htc/m8/prebuilt/dt.img:dt.img

# vendor/twrp/config/packages.mk pulls bash, nano, vim, htop and powertop
# in for external/libncurses's terminfo data; ncurses install runs through
# ALL_DEFAULT_INSTALLED_MODULES unconditionally on any project inclusion,
# not gated by PRODUCT_PACKAGES, and measured 12 MiB in the a11chl port
# (job 088, BUILD_PROGRESSION.md). None of the five is needed to install a
# ROM, sideload a zip, run MTP, or back up/restore, so all five are cut.
PRODUCT_PACKAGES -= bash nano vim htop powertop

## Device identifier. This must come after all inclusions.
PRODUCT_DEVICE := m8
PRODUCT_NAME := twrp_m8
PRODUCT_BRAND := htc
PRODUCT_MODEL := HTC One (M8)
PRODUCT_MANUFACTURER := HTC

# The stock MM fingerprint this device's own bootimage reports
# (ro.bootimage.build.fingerprint, HTC/blobs/device-getprop.txt:414).
BUILD_FINGERPRINT := htc/sprint_wwe/htc_m8whl:6.0/MRA58K/682910.3:user/release-keys
