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

Both are prebuilt blobs unpacked directly from the M8 boot.img that pairs
build 387's ramdisk, cmdline and dt.img with kernel 91cbf4854e0f (boot.img
sha256 `3332e6ea9be0f5d817fc03a2de6b198c68aa91091f6a79462c8371168602900f`),
not built from a dts or kernel source tree in this repo. They stay a matched
pair, because a flashed recovery boots with its own image's dt.img:

- `prebuilt/kernel`: sha256
  `5c52dbe383a93470cd0e714d3348f03be84311863a88aa80f0668366a3901334`,
  `Linux version 3.4.113-g91cbf4854e0f ... clang version 22.0.0 ... #3 SMP
  PREEMPT Mon Oct 5 20:30:00 PDT 2026`, built with build 387's kernel
  `.config` and toolchain from
  `Oichkatzelesfrettschen/android_kernel_htc_msm8974`
  @`91cbf4854e0f43e05757c5a05b8c545ce5581955` (branch `lineage-22.2-m8`).
- `prebuilt/dt.img`: sha256
  `539794f55cec8b0bf8b5d712b0e20e15305d0b504b8ecc29553635853d1e92a0`, the
  QCDT multi-entry device-tree blob.

hboot 3.19 boots the recovery partition with
`androidboot.mode=offmode_charging` when USB is inserted into a powered-off
phone and when its RECOVERY menu entry follows a USB-insertion power-on.
The kernel's `board_mfg_mode()` then skips probing the touch controller
and the sensor hub, which leaves TWRP without touch.
`BOARD_KERNEL_CMDLINE` carries `htc.recovery_boot=1`, which the kernel's
`arch/arm/mach-msm/devices_cmdline.c` maps to `MFG_MODE_RECOVERY` for that
boot, so every recovery-partition boot runs TWRP with its input devices.

`drivers/usb/gadget/android.c` (the composite gadget driver
`CONFIG_USB_G_ANDROID` selects) `#include`s `f_fs.c` directly and calls
`functionfs_init()`, so FunctionFS is compiled into this kernel's USB
gadget regardless of the standalone `CONFIG_USB_FUNCTIONFS` module option,
which `m8_defconfig` leaves unset. This same composite driver's own
`htc_attr.c` extension gates real function binding behind a store on
`usb_function_switch` (`android_switch_function()`, which no-ops unless
that bitmask is written after the base `functions`/`enable` pair);
`device/htc/msm8974-common`'s own ROM-side `init.qcom.usb.rc` writes it on
every single function transition, and `bootable_recovery@android-14.1`'s
generic default `etc/init.recovery.usb.rc` does not write it at all.
`TW_EXCLUDE_DEFAULT_USB_INIT` therefore replaces that default with
`TeamWin/android_device_htc_m8@android-8.1`'s own
`recovery/root/init.recovery.usb.rc`, the file that shipped in the
official `twrp-3.7.0_9-0-m8.img`, carried forward unmodified (it already
writes `usb_function_switch` on every transition, with HTC's own
idVendor/idProduct). `recovery/root/init.recovery.qcom.rc` adds the three
properties (`sys.usb.ffs.aio_compat`, `persist.adb.nonblocking_ffs`,
`ro.adb.nonblocking_ffs`) `device/htc/msm8974-common`'s own ROM-side
init.recovery.qcom.rc sets for the same adbd-over-FFS path.

## system/core: the cgroup2 per-service fatal path

`twrp-14`/`twrp-14.1`'s `init` aborts a service whose `createProcessGroup()`
fails (the roadmap's blockers table names this as a real, unresolved risk
for a kernel lacking full cgroup2 support). `bootable_recovery`'s own
`system/core/init/service.cpp` on this manifest carries that fatal path
unmodified. `device/htc/msm8974-common`'s own ROM build
(`lineage-22.2-m8`) does not carry it: its `init/service.cpp` wraps the
same fatal return in `#if 0`, a byte-for-byte match (context, not just
message) of `Ultra-Legacy-Hippeastrum/android_system_core@lineage-22.2`
commit `99dd39e391246da743cf5ce32f545f294f819600`, present in the tree
that built the currently-flashed image. `ANDROID15_PORT_LOG.md` records
that this commit reached the ROM by a wholesale cherry-pick from
Ultra-Legacy-Hippeastrum's platform for legacy devices generally, not as
a fix written for a failure this device specifically hit, so its presence
in the ROM does not by itself prove `createProcessGroup()` fails on this
kernel. It is carried into TWRP's own `init` regardless
(`Oichkatzelesfrettschen/android_system_core-m8-twrp`, branch
`m8-cgroup2-nonfatal-v2`, pinned in `htc-workbench`'s
`manifests/twrp14.1-m8-local_manifest.xml` alongside this device tree
and `android_bootable_recovery-m8-twrp`, a cherry-pick of the same
upstream commit), because it matches the init
the flashed ROM actually runs and only turns an abort into a logged
error -- strictly safer for a recovery build whether or not the failure
is ever reached in practice. The recoveryimage offline verification gate
asserts the fix reached the built `init` binary by checking for the
fatal path's now-unreachable log string, absent once the `#if 0` block
compiles it out; whether this device's `createProcessGroup()` ever
actually fails is the RAM-boot test's own falsifier
(`grep 'createProcessGroup(' recovery.log dmesg` for "failed for
service" after boot).

## Boot header

`BoardConfig.mk`'s cmdline, base, pagesize and the three load offsets are
read back with `unpackbootimg` from the flashed build's own boot.img
directly, not assumed from `device/htc/msm8974-common`'s
`BoardConfigCommon.mk`: that tree's declared `BOARD_KERNEL_CMDLINE`
additions do not all survive into the final image (the flashed header
carries no `androidboot.selinux` token, and does carry `loop.max_part=7`,
the adoptable-storage support `BoardConfigCommon.mk` adds for the same
reason, `HARDWARE_REFERENCE_MATRIX.md` row 20a). Nor from the frozen
`android-8.1` tree's own values, which differ further still (that tree's
cmdline lacks `console=none`/`zcache` in the same order and its kernel
offset macro names differ).

`--dt`'s QCDT packer is `tools/mkbootimg_dt`, bound through
`BOARD_CUSTOM_MKBOOTIMG` (`build/make/core/config.mk`, confirmed present
on this manifest), because upstream `system/tools/mkbootimg` dropped the
v0 header's `--dt` flag for the flattened `--dtb` (boot header v1+). The
tool is a from-scratch reimplementation (no upstream file copied), the
same design `Oichkatzelesfrettschen/android_device_htc_a11chl`'s own
`tools/mkbootimg_dt` already proved on this manifest generation.
`build/make/core/Makefile` makes `$(PRODUCT_OUT)/dt.img` a hard ninja
prerequisite of `recovery.img` whenever `BOARD_KERNEL_SEPARATED_DT` is
true, unconditionally on `BOARD_KERNEL_PREBUILT_DT` (only
`vendor/twrp/build/tasks/dt_image.mk`'s own `dtbToolCM` rule is gated on
that flag); `twrp_m8.mk`'s `PRODUCT_COPY_FILES` entry gives that target a
producer by copying the checked-in `prebuilt/dt.img` there directly.

## fstab

`recovery.fstab`'s by-name paths are lifted from
`device/htc/msm8974-common`'s own `rootdir/etc/fstab.qcom`, the fstab
this device's own ueventd already builds those
`/dev/block/platform/msm_sdcc.1/by-name/*` links for. `/cache` is ext4,
not the f2fs that tree declares as its preferred type: this partition's
f2fs superblock is invalid on the flashed device
(`libfs_mgr`'s own fallback log,
`evidence/camera-root-cause/logcat-kernel.txt`, "Invalid f2fs superblock
... mount(...,ext4)=0: Success"), so the physical format is ext4
regardless of the declared preference.

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
