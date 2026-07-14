# OrangeFox Recovery for Moto G15 (lamu)

Self-contained OrangeFox Recovery device tree for the Moto G15 (`lamu`). It
targets the OrangeFox `fox_12.1` manifest and builds recovery as the recovery
fragment of a header-v4 `vendor_boot` image.

## Current phase

Phase 1 is a clean, reproducible baseline derived from the previously booting
14.1 bring-up and the installed LineageOS 23.2 images. It still needs its first
`fox_12.1` GitHub Actions build and on-device validation.

Included in this repository:

- the LineageOS 23.2 DTB;
- all 177 modules needed by the normal and recovery vendor ramdisks;
- the exact normal/recovery module load lists;
- the recovery fstab and MediaTek recovery init fragment;
- all 12 touchscreen firmware files present in the LineageOS recovery ramdisk.

No companion `mt6768-common` device tree or Motorola vendor repository is
required by this recovery tree.

## Build

The GitHub Actions workflow is deliberately fixed to `fox_12.1`. Start it with
**Actions -> Build OrangeFox for lamu -> Run workflow**. Ccache is disabled by
default to preserve runner disk space.

Equivalent build commands after syncing OrangeFox are:

```bash
export ALLOW_MISSING_DEPENDENCIES=true
export FOX_BUILD_DEVICE=lamu
export LC_ALL=C
source build/envsetup.sh
lunch twrp_lamu-eng
mka adbd vendorbootimage
```

Every successful workflow run uploads a checkpoint containing the generated
OrangeFox artifacts, `vendor_boot.img`, the recovery ramdisk fragment when
available, the full build log, SHA-256 checksums, and a snapshot of this exact
device tree revision.

## Testing

Read [TESTING.md](TESTING.md) before flashing. Prefer flashing only the
`vendor_boot:recovery` ramdisk fragment from fastbootd; that preserves the
LineageOS generic vendor ramdisk and DTB.

## Sources and credits

- Initial OrangeFox bring-up: `askell091`.
- LineageOS device/kernel/vendor work and current prebuilts:
  `moto-mediatek-devs`.
- OrangeFox Recovery Project and TeamWin Recovery Project.

The exact local source paths and hashes used for the prebuilts are documented
in [prebuilts/PROVENANCE.md](prebuilts/PROVENANCE.md).
