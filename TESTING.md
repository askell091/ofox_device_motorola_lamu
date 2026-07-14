# Testing checkpoints on lamu

Keep the known-good LineageOS `vendor_boot.img`, a working USB cable, and
bootloader fastboot access available throughout testing.

## Preferred installation for development builds

The header-v4 recovery fragment avoids replacing the normal LineageOS vendor
ramdisk and DTB:

```bash
adb reboot fastboot
fastboot devices
fastboot getvar current-slot
fastboot flash vendor_boot:recovery vendor_ramdisk_recovery.cpio
fastboot reboot recovery
```

Do not use `fastboot boot`; lamu does not support that path for this recovery.
Do not flash the full `vendor_boot.img` unless the recovery fragment is absent
or a full-image test is explicitly required.

## Minimum report after each boot

Run these from the host while OrangeFox is open:

```bash
adb devices
adb shell getprop ro.boot.slot_suffix
adb shell getprop ro.crypto.state
adb shell getprop ro.crypto.type
adb shell mount
adb shell df -h
adb shell ls -la /data /data/media /metadata
adb shell ls -la /dev/block/by-name
adb pull /tmp/recovery.log
adb logcat -d > logcat.txt
adb shell dmesg > dmesg.txt
```

Also record whether each of these works: display, touch, brightness, normal
ADB, sideload, internal storage, microSD, USB OTG, MTP, battery/charging,
vibration, flashlight, fastbootd, reboot targets, and decryption prompt.

If recovery does not boot, record the exact flashing command, active slot,
host fastboot output, and the visible behavior (black screen, logo, reboot, or
bootloader fallback).

## Phase 2: metadata/FBE decryption

The first crypto-enabled build starts the installed Android 16 Trustonic
KeyMint and Gatekeeper through a compatibility launcher. Do not format or wipe
`/data` when testing it. A failed mount is a diagnostic result, not evidence
that userdata is corrupt.

After ADB becomes available, collect:

```bash
adb shell getprop ro.orangefox.crypto_enabled
adb shell getprop lamu.crypto.compat.ready
adb shell getprop ro.vendor.trustonic.ready
adb shell getprop ro.crypto.fs_crypto_blkdev
adb shell ps -A | grep -E 'mcDriverDaemon|linker64|keystore2|servicemanager'
adb shell mount | grep -E ' /data | /metadata | /odm | /vendor | /system_root '
adb shell ls -la /data/media/0
adb pull /tmp/recovery.log recovery-crypto.log
adb logcat -d > logcat-crypto.txt
adb shell dmesg > dmesg-crypto.txt
```

Expected compatibility properties are `ro.orangefox.crypto_enabled=1`,
`lamu.crypto.compat.ready=1`, and `ro.vendor.trustonic.ready=true`. If the UI
stays at the OrangeFox logo, leave the device connected for at least 30
seconds and collect the three logs above before rebooting.
