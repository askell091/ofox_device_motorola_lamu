/*
 * Copyright (C) 2019 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#pragma once

#include <android/hardware/boot/1.2/IBootControl.h>
#include <libboot_control/libboot_control.h>

namespace android::hardware::boot::V1_2::implementation {

using ::android::hardware::Return;
using ::android::hardware::Void;
using ::android::hardware::boot::V1_0::BoolResult;
using ::android::hardware::boot::V1_1::MergeStatus;
using ::android::hardware::boot::V1_2::IBootControl;

class BootControl final : public IBootControl {
public:
  bool Init();

  Return<uint32_t> getNumberSlots() override;
  Return<uint32_t> getCurrentSlot() override;
  Return<void> markBootSuccessful(markBootSuccessful_cb callback) override;
  Return<void> setActiveBootSlot(uint32_t slot,
                                 setActiveBootSlot_cb callback) override;
  Return<void> setSlotAsUnbootable(uint32_t slot,
                                   setSlotAsUnbootable_cb callback) override;
  Return<BoolResult> isSlotBootable(uint32_t slot) override;
  Return<BoolResult> isSlotMarkedSuccessful(uint32_t slot) override;
  Return<void> getSuffix(uint32_t slot, getSuffix_cb callback) override;
  Return<bool> setSnapshotMergeStatus(MergeStatus status) override;
  Return<MergeStatus> getSnapshotMergeStatus() override;
  Return<uint32_t> getActiveBootSlot() override;

private:
  android::bootable::BootControl impl_;
};

} // namespace android::hardware::boot::V1_2::implementation
