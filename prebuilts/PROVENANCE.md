# Prebuilt provenance

The Phase 1 prebuilts match the LineageOS 23.2 images installed on the test
device. They are intentionally vendored here so the OrangeFox tree has no
companion device or vendor repository dependencies.

Local sources used to construct this tree:

```text
Sources/askell091/android_device_lamu-ofrp/prebuilts/kernel/6.6
Sources/askell091/android_vendor_motorola_mt6768-common-ofrp/proprietary/recovery/root/vendor/firmware
Images/LineageOS/Extracted/vendor_boot
Sources/moto-mediatek-devs/android_device_motorola_mt6768-common/init/fstab.mt6768
```

Verified facts:

- `dtb.img` is byte-identical to `Images/LineageOS/Extracted/vendor_boot/dtb`.
- All 177 `.ko` files are byte-identical to the modules in the LineageOS
  generic vendor ramdisk.
- All 12 touchscreen firmware files are byte-identical to the files in the
  LineageOS recovery vendor ramdisk.
- `vendor_ramdisk.modules.load` and
  `vendor_ramdisk.modules.load.recovery` match the LineageOS ramdisk lists.

Important DTB hashes:

```text
d80c5958bd23a5e5d2f939aec4813a031713bd079180f7334e2f943529505557  LineageOS 23.2 / vendored dtb.img
e7ff73a6e923d21136834a4905439475b6b5622e560e7042fcea2e4e5271da3d  stock dtb (not used)
```

Refresh the complete checksum manifest with:

```bash
tools/verify-prebuilts.sh --write
```
