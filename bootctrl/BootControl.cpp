/*
 * Copyright (C) 2019 The Android Open Source Project
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "lamu-bootctrl12"

#include "BootControl.h"

#include "emmc_bootpart.h"

#include <android-base/logging.h>

namespace android::hardware::boot::V1_2::implementation {

using ::android::hardware::boot::V1_0::CommandResult;

bool BootControl::Init() { return impl_.Init(); }

Return<uint32_t> BootControl::getNumberSlots() {
  return impl_.GetNumberSlots();
}

Return<uint32_t> BootControl::getCurrentSlot() {
  return impl_.GetCurrentSlot();
}

Return<void> BootControl::markBootSuccessful(markBootSuccessful_cb callback) {
  CommandResult result;
  result.success = impl_.MarkBootSuccessful();
  result.errMsg = result.success ? "Success" : "Operation failed";
  callback(result);
  return Void();
}

Return<void> BootControl::setActiveBootSlot(uint32_t slot,
                                            setActiveBootSlot_cb callback) {
  CommandResult result;
  result.success = false;
  if (impl_.IsValidSlot(slot)) {
    const uint32_t previous_slot = impl_.GetActiveBootSlot();
    if (impl_.SetActiveBootSlot(slot)) {
      result.success = lamu::boot::SetEmmcBootRegion(slot);
      if (!result.success && impl_.IsValidSlot(previous_slot) &&
          !impl_.SetActiveBootSlot(previous_slot)) {
        LOG(ERROR) << "Failed to roll back A/B metadata to slot "
                   << previous_slot;
      }
    }
  }
  result.errMsg = result.success ? "Success" : "Operation failed";
  callback(result);
  return Void();
}

Return<void> BootControl::setSlotAsUnbootable(uint32_t slot,
                                              setSlotAsUnbootable_cb callback) {
  CommandResult result;
  result.success = impl_.IsValidSlot(slot) && impl_.SetSlotAsUnbootable(slot);
  result.errMsg = result.success ? "Success" : "Operation failed";
  callback(result);
  return Void();
}

Return<BoolResult> BootControl::isSlotBootable(uint32_t slot) {
  if (!impl_.IsValidSlot(slot))
    return BoolResult::INVALID_SLOT;
  return impl_.IsSlotBootable(slot) ? BoolResult::TRUE : BoolResult::FALSE;
}

Return<BoolResult> BootControl::isSlotMarkedSuccessful(uint32_t slot) {
  if (!impl_.IsValidSlot(slot))
    return BoolResult::INVALID_SLOT;
  return impl_.IsSlotMarkedSuccessful(slot) ? BoolResult::TRUE
                                            : BoolResult::FALSE;
}

Return<void> BootControl::getSuffix(uint32_t slot, getSuffix_cb callback) {
  hidl_string suffix;
  if (const char *value = impl_.GetSuffix(slot); value != nullptr) {
    suffix = value;
  }
  callback(suffix);
  return Void();
}

Return<bool> BootControl::setSnapshotMergeStatus(MergeStatus status) {
  return impl_.SetSnapshotMergeStatus(status);
}

Return<MergeStatus> BootControl::getSnapshotMergeStatus() {
  return impl_.GetSnapshotMergeStatus();
}

Return<uint32_t> BootControl::getActiveBootSlot() {
  return impl_.GetActiveBootSlot();
}

} // namespace android::hardware::boot::V1_2::implementation
