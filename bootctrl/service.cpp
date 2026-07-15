/*
 * Copyright (C) 2019 The Android Open Source Project
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "lamu-bootctrl12"

#include "BootControl.h"

#include <android-base/logging.h>
#include <cstdlib>
#include <hidl/HidlTransportSupport.h>

using android::OK;
using android::sp;
using android::hardware::configureRpcThreadpool;
using android::hardware::joinRpcThreadpool;
using android::hardware::boot::V1_2::implementation::BootControl;

int main(int, char **argv) {
  android::base::InitLogging(argv, android::base::KernelLogger);
  sp<BootControl> service = new BootControl();
  if (!service->Init()) {
    LOG(ERROR) << "Unable to initialize lamu Boot Control";
    return EXIT_FAILURE;
  }

  configureRpcThreadpool(1, true);
  if (service->registerAsService("default") != OK) {
    LOG(ERROR) << "Unable to register lamu Boot Control HIDL service";
    return EXIT_FAILURE;
  }

  LOG(INFO) << "lamu Boot Control HIDL 1.2 service ready";
  joinRpcThreadpool();
  return EXIT_FAILURE;
}
