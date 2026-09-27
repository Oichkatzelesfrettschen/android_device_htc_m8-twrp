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
  cross toolchain. This is a rebuild from that commit's source, not an
  extraction from the flashed binary: kernel builds are not
  byte-reproducible across build environments, so this sha256
  (`4878c9b7d1e21c5b9460ed84e8e16b97893f8faffb10117ca3a9f2dbc962d240`)
  differs from the flashed image's own kernel blob
  (`316967b3a3ad181cb11ffd3b111e176f3f42ceeaca25811eda7dd66bd6a90c1f`, from
  build076's own boot.img, unpacked this session).
  `arch/arm/configs/m8_defconfig` (and this same commit family's own
  captured `.config`, `~/Github/m8/lineage-22.2/out/target/product/m8/obj/KERNEL_OBJ/.config`)
  leave `CONFIG_USB_FUNCTIONFS` unset in favor of `CONFIG_USB_G_ANDROID=y`:
  the FunctionFS AIO source support cited below exists in this kernel's
  tree, but the shipped configuration does not build that gadget driver in.
  `bootable_recovery@android-14.1`'s own default
  `etc/init.recovery.usb.rc` already targets `/sys/class/android_usb/android0/*`
  (not configfs), matching this kernel's actual gadget driver, so
  `TW_EXCLUDE_DEFAULT_USB_INIT` stays unset and no device-specific USB rc
  is carried (TeamWin's `android-8.1` tree's own
  `recovery/root/init.recovery.usb.rc`, deleted here, wrote to the same
  sysfs nodes with HTC's own idVendor/idProduct; the default's generic
  Google IDs enumerate `adb` over Linux `usbfs` identically, since the host
  matches by the ADB interface class, not by VID/PID).
- `prebuilt/dt.img`: the QCDT multi-entry device-tree blob unpacked
  directly from build076's own boot.img (sha256
  `f7437c450d47ba902caf4aa7008b2ee6627df14e1220db483af48a52f59aca99`,
  `HARDWARE_REFERENCE_MATRIX.md` row 16/276), sha256
  `0721ba9b1e40f07c12f7eeac8bd3dabd83272a2c751f72eb664e2b2f35b57201`,
  matching byte-for-byte.

## Verified non-issues

Two risks the porting roadmap left open, checked this session and closed
without a code change:

- **cgroup2 per-service fatal path** (`twrp-14`/`twrp-14.1` only,
  `TWRP_NEWEST_ROADMAP.md`'s blockers table): this kernel's compat cgroup2
  filesystem (`d21c4ade876`) mounts a real `cgroup2` filesystem at boot, so
  `createProcessGroup()` succeeds through the ordinary path and never
  reaches the fatal branch; `~/Github/m8/lineage-22.2/system/core` carries
  no "process group" revert commit (`git log --grep`, empty), and needs
  none, because the mount itself succeeds. This mechanism is generic AOSP
  `init` code, shared between the ROM's ramdisk and TWRP's own ramdisk on
  this manifest generation, not something either side sets up specially.
- **USB gadget mechanism**: see `prebuilt/kernel` above.

## Boot header

`BoardConfig.mk`'s cmdline, base, pagesize and the three load offsets are
read back with `unpackbootimg` from build076's own boot.img directly, not
assumed from `device/htc/msm8974-common`'s `BoardConfigCommon.mk`: that
tree's declared `BOARD_KERNEL_CMDLINE` additions do not all survive into
the final image (the flashed header carries no `androidboot.selinux`
token, and does carry `loop.max_part=7`, the adoptable-storage support
`BoardConfigCommon.mk` adds for the same reason,
`HARDWARE_REFERENCE_MATRIX.md` row 20a). Nor from the frozen `android-8.1`
tree's own values, which differ further still (that tree's cmdline lacks
`console=none`/`zcache` in the same order and its kernel offset macro
names differ). `--dt`'s QCDT packer is
`tools/mkbootimg_dt`, bound through `BOARD_CUSTOM_MKBOOTIMG`
(`build/make/core/config.mk:683-686` on this manifest, confirmed present),
because upstream `system/tools/mkbootimg` dropped the v0 header's `--dt`
flag for the flattened `--dtb` (boot header v1+). The tool is a from-scratch
reimplementation (no upstream file copied), the same design
`Oichkatzelesfrettschen/android_device_htc_a11chl`'s own `tools/mkbootimg_dt`
already proved on this manifest generation.

## fstab

`recovery.fstab`'s by-name paths are lifted from the tree that actually
built build076, `~/Github/m8/lineage-22.2/device/htc/msm8974-common`'s own
`rootdir/etc/fstab.qcom`, the fstab this device's own ueventd already
builds those `/dev/block/platform/msm_sdcc.1/by-name/*` links for.

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
