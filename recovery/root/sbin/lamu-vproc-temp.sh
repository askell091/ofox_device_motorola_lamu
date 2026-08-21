#!/system/bin/sh

# Expose the calibrated MT6358 VPROC regulator temperature to OrangeFox
# without loading the monolithic thermal_monitor/PPM kernel stack.

readonly OUTPUT=/tmp/lamu-vproc-temp
readonly REGMAP=/sys/kernel/debug/regmap/1000d000.pwrap/registers

find_raw_path() {
    for path in /sys/bus/iio/devices/iio:device*/in_voltage7_VPROC_TEMP_input; do
        if [ -r "$path" ]; then
            RAW_PATH="$path"
            return 0
        fi
    done

    return 1
}

read_register() {
    line="$(grep -i "^$1:" "$REGMAP" 2>/dev/null | head -n 1)"
    value="${line#*: }"

    case "$value" in
        ""|*[!0-9a-fA-F]*) return 1 ;;
    esac

    printf '%d\n' "$((0x$value))"
}

read_calibration() {
    # Defaults used by the MediaTek driver when calibration is unavailable.
    ADC_CALI_EN=0
    DEGC_CALI=50
    O_VTS_3=1600
    O_SLOPE=0
    O_SLOPE_SIGN=0
    EFUSE_ID=0

    mounted_debugfs=0
    if ! grep -q ' /sys/kernel/debug debugfs ' /proc/mounts; then
        if mount -t debugfs debugfs /sys/kernel/debug >/dev/null 2>&1; then
            mounted_debugfs=1
        fi
    fi

    if [ -r "$REGMAP" ]; then
        reg_11ce="$(read_register 11ce)"
        reg_11d2="$(read_register 11d2)"
        reg_11d4="$(read_register 11d4)"
        reg_11d8="$(read_register 11d8)"

        if [ -n "$reg_11ce" ] && [ -n "$reg_11d2" ] &&
           [ -n "$reg_11d4" ] && [ -n "$reg_11d8" ]; then
            ADC_CALI_EN=$(((reg_11ce >> 8) & 1))
            DEGC_CALI=$((reg_11ce & 0x3f))
            O_VTS_3=$((reg_11d8 & 0x1fff))
            O_SLOPE_SIGN=$(((reg_11d2 >> 8) & 1))
            O_SLOPE=$((reg_11d2 & 0x3f))
            EFUSE_ID=$(((reg_11d4 >> 4) & 1))
        fi
    fi

    if [ "$mounted_debugfs" -eq 1 ]; then
        umount /sys/kernel/debug >/dev/null 2>&1
    fi

    if [ "$ADC_CALI_EN" -eq 0 ]; then
        DEGC_CALI=50
        O_VTS_3=1600
        O_SLOPE=0
        O_SLOPE_SIGN=0
    fi

    if [ "$EFUSE_ID" -eq 0 ]; then
        O_SLOPE=0
    fi

    if [ "$DEGC_CALI" -lt 38 ] || [ "$DEGC_CALI" -gt 60 ]; then
        DEGC_CALI=53
    fi

    factor=1863
    if [ "$O_SLOPE_SIGN" -eq 0 ]; then
        SLOPE2=$((-(factor + O_SLOPE)))
        intercept_denominator=$((-(factor + O_SLOPE * 10)))
    else
        SLOPE2=$((-(factor - O_SLOPE)))
        intercept_denominator=$((-(factor - O_SLOPE * 10)))
    fi

    vbe=$((-((O_VTS_3 * 1800 / 4096)) * 1000))
    INTERCEPT=$((vbe * 1000 / intercept_denominator + DEGC_CALI * 500))
}

update_temperature() {
    raw="$(cat "$RAW_PATH" 2>/dev/null)"
    case "$raw" in
        ""|*[!0-9]*) return 1 ;;
    esac

    temperature=$((INTERCEPT + 1000000 * raw / SLOPE2))

    # Match the validity range enforced by the MediaTek PMIC thermal driver.
    if [ "$temperature" -lt -50000 ] || [ "$temperature" -gt 150000 ]; then
        return 1
    fi

    printf '%d\n' "$temperature" > "$OUTPUT"
    chmod 0444 "$OUTPUT"
}

attempt=0
while ! find_raw_path; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 5 ]; then
        exit 1
    fi
    sleep 1
done

read_calibration
update_temperature || exit 1

if [ "$1" = "--once" ]; then
    exit 0
fi

while sleep 5; do
    update_temperature
done
