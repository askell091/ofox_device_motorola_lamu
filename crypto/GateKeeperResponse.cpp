/*
 * Copyright (C) 2019 The Android Open Source Project
 * SPDX-License-Identifier: Apache-2.0
 */

#include <gatekeeper/GateKeeperResponse.h>

#include <binder/Parcel.h>

#include <algorithm>

namespace android::service::gatekeeper {

status_t GateKeeperResponse::readFromParcel(const Parcel* in) {
    if (in == nullptr) return BAD_VALUE;

    timeout_ = 0;
    should_reenroll_ = false;
    payload_.clear();
    response_code_ = ResponseCode(in->readInt32());
    if (response_code_ == ResponseCode::OK) {
        should_reenroll_ = in->readInt32();
        ssize_t length = in->readInt32();
        if (length > 0) {
            length = in->readInt32();
            const uint8_t* buffer = reinterpret_cast<const uint8_t*>(
                in->readInplace(length));
            if (buffer == nullptr) return BAD_VALUE;
            payload_.resize(length);
            std::copy(buffer, buffer + length, payload_.data());
        }
    } else if (response_code_ == ResponseCode::RETRY) {
        timeout_ = in->readInt32();
    }
    return NO_ERROR;
}

status_t GateKeeperResponse::writeToParcel(Parcel* out) const {
    if (out == nullptr) return BAD_VALUE;

    out->writeInt32(int32_t(response_code_));
    if (response_code_ == ResponseCode::OK) {
        out->writeInt32(should_reenroll_);
        out->writeInt32(payload_.size());
        if (!payload_.empty()) {
            out->writeInt32(payload_.size());
            uint8_t* buffer = reinterpret_cast<uint8_t*>(
                out->writeInplace(payload_.size()));
            if (buffer == nullptr) return BAD_VALUE;
            std::copy(payload_.begin(), payload_.end(), buffer);
        }
    } else if (response_code_ == ResponseCode::RETRY) {
        out->writeInt32(timeout_);
    }
    return NO_ERROR;
}

}  // namespace android::service::gatekeeper
