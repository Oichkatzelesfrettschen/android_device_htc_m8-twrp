# device/htc/m8

TWRP device tree for the HTC One M8 (m8whl, Sprint/CDMA variant), Qualcomm
MSM8974 (Snapdragon 801, quad-core Krait 400, Adreno 330), 32-bit, kernel
3.4.113. Branch: `twrp-14.1`
(minimal-manifest-twrp/platform_manifest_twrp_aosp), producing
`TW_MAIN_VERSION_STR` `3.7.1_14`.

Seeded from `TeamWin/android_device_htc_m8@android-8.1` (the unified tree
that produced the official `twrp-3.7.0_9-0-m8.img`), re-targeted at the
newest minimal manifest.

## Kernel and dt.img

Both are prebuilt blobs, not built from a dts source tree in this repo:

- `prebuilt/kernel`: `arch/arm/boot/zImage` built from
  `Oichkatzelesfrettschen/android_kernel_htc_msm8974`
  @`4140df22f96e040e5dd51d196e9bd65ad784738c` (branch
  `kgsl-detach-recovery-ptp-interface`), the exact commit this device's
  currently-flashed `lineage-22.2-20260926-UNOFFICIAL-m8` build's own
  `/proc/version` identifies (`Linux version 3.4.113-g4140df22`,
  `Projects/Android/HTC/evidence/watchdog-bite-nonrepro-20260926`). Built
  with `m8_defconfig` and the LineageOS 18.1 GCC 4.9.x (20150123) prebuilt
  cross toolchain.
  sha256 `4878c9b7d1e21c5b9460ed84e8e16b97893f8faffb10117ca3a9f2dbc962d240`.
- `prebuilt/dt.img`: the QCDT multi-entry device-tree blob unpacked from
  this device's own flashed boot.img. Confirmed byte-identical
  (sha256 `0721ba9b1e40f07c12f7eeac8bd3dabd83272a2c751f72eb664e2b2f35b57201`)
  across every M8 kernel build sampled this session, including one built
  from a kernel commit roughly 2000 commits ahead of the pin above -- the
  QCDT table is a static hardware description, not kernel-version-dependent.

## Boot header

`BoardConfig.mk`'s cmdline, base, pagesize and the three load offsets come
from `device/htc/msm8974-common@lineage-22.2-m8`'s own
`BoardConfigCommon.mk` (the ROM tree this device actually runs), not from
the frozen `android-8.1` tree's own values, which differ (that tree's
cmdline lacks `console=none`/`zcache` in the same order and its kernel
offset macro names differ). `--dt`'s QCDT packer is
`tools/mkbootimg_dt`, bound through `BOARD_CUSTOM_MKBOOTIMG`
(`build/make/core/config.mk:683-686` on this manifest, confirmed present),
because upstream `system/tools/mkbootimg` dropped the v0 header's `--dt`
flag for the flattened `--dtb` (boot header v1+). The tool is a from-scratch
reimplementation (no upstream file copied), the same design
`Oichkatzelesfrettschen/android_device_htc_a11chl`'s own `tools/mkbootimg_dt`
already proved on this manifest generation.

## fstab

`recovery.fstab`'s by-name paths are lifted from
`device/htc/msm8974-common@lineage-22.2-m8`'s own `rootdir/etc/fstab.qcom`,
the fstab this device's own ueventd already builds those
`/dev/block/platform/msm_sdcc.1/by-name/*` links for.

## Scope cuts

No `TW_INCLUDE_CRYPTO`: this device's `ro.crypto.state` reads `unsupported`
on its currently-flashed Android 15 build and `unencrypted` on its earlier
stock Marshmallow build; no ROM in its history ships FDE/FBE userdata.
`TW_EXCLUDE_NANO`/`TW_EXCLUDE_BASH` cut the ncurses-terminfo tax neither
tool needs to install a ROM, sideload, run MTP, or back up/restore.

Build: `source build/envsetup.sh && lunch twrp_m8-ap2a-eng && make -j$(nproc) recoveryimage`.
(`ap2a` is a release-config name under `build/release/`, required by this
manifest's 3-part `<product>-<release>-<variant>` lunch combo; the older
2-part form a11chl's own `twrp-11` tree uses predates this requirement.)
