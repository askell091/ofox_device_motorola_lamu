#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/motorola/lamu

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_ramdisk.mk)
$(call inherit-product, vendor/twrp/config/common.mk)

PRODUCT_DEVICE := lamu
PRODUCT_NAME := twrp_lamu
PRODUCT_BRAND := motorola
PRODUCT_MANUFACTURER := motorola
PRODUCT_MODEL := moto g15

PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_BUILD_SUPER_PARTITION := false
ENABLE_VIRTUAL_AB := true

PRODUCT_SOONG_NAMESPACES += \
    $(DEVICE_PATH)

PRODUCT_PACKAGES += \
    adbd.recovery \
    charger.recovery \
    e2fsck_ramdisk \
    fastbootd \
    fsck.f2fs.vendor_ramdisk \
    init_second_stage.recovery \
    init.environ.rc \
    lamu_gatekeeper16 \
    ld.config.recovery.txt \
    linker.recovery \
    recovery \
    shell_and_utilities_recovery \
    update_engine_sideload \
    update_verifier \
    watchdogd.recovery \
    fstab.mt6768 \
    fstab.mt6768.vendor_ramdisk

PRODUCT_COPY_FILES += \
    bootable/recovery/gui/theme/extra-languages/fonts/DroidSansFallback.ttf:$(TARGET_COPY_OUT_RECOVERY)/root/twres/fonts/DroidSansFallback.ttf \
    $(DEVICE_PATH)/init/init.recovery.mt6768.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.mt6768.rc \
    $(DEVICE_PATH)/recovery/root/twres/images/Default/About/maintainer.png:$(TARGET_COPY_OUT_RECOVERY)/root/twres/images/Default/About/maintainer.png \
    $(DEVICE_PATH)/recovery/root/sbin/fsck.f2fs16.sh:$(TARGET_COPY_OUT_RECOVERY)/root/sbin/fsck.f2fs16.sh \
    $(DEVICE_PATH)/recovery/root/sbin/lamu-device-vintf.xml:$(TARGET_COPY_OUT_RECOVERY)/root/sbin/lamu-device-vintf.xml \
    $(DEVICE_PATH)/recovery/root/sbin/lamu-framework-vintf.xml:$(TARGET_COPY_OUT_RECOVERY)/root/sbin/lamu-framework-vintf.xml \
    $(DEVICE_PATH)/recovery/root/sbin/resyncapex.sh:$(TARGET_COPY_OUT_RECOVERY)/root/sbin/resyncapex.sh \
    $(DEVICE_PATH)/recovery/root/sbin/vold_prepare_subdirs16.sh:$(TARGET_COPY_OUT_RECOVERY)/root/sbin/vold_prepare_subdirs16.sh \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/ILITEK_FW.hex:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/firmware/ILITEK_FW.hex \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/chipone_firmware.bin:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/firmware/chipone_firmware.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/chipone_limit.bin:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/firmware/chipone_limit.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/dijin_hdl_firmware.img:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/firmware/dijin_hdl_firmware.img \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/dijin_hdl_firmware_test.img:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/firmware/dijin_hdl_firmware_test.img \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/dijin_novatek_ts_fw.bin:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/firmware/dijin_novatek_ts_fw.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/dijin_novatek_ts_mp.bin:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/firmware/dijin_novatek_ts_mp.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/gt1151_default_firmware2.img:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/firmware/gt1151_default_firmware2.img \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/tianma_hdl_firmware.img:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/firmware/tianma_hdl_firmware.img \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/tianma_hdl_firmware_test.img:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/firmware/tianma_hdl_firmware_test.img \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/tianma_novatek_ts_fw.bin:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/firmware/tianma_novatek_ts_fw.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/tianma_novatek_ts_mp.bin:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/firmware/tianma_novatek_ts_mp.bin

TARGET_SCREEN_WIDTH := 1080
TARGET_SCREEN_HEIGHT := 2400
