/*
 * Copyright (C) 2019 The Android Open Source Project
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <binder/Parcelable.h>

#include <cstdint>
#include <utility>
#include <vector>

namespace android::service::gatekeeper {

enum class ResponseCode : int32_t {
    ERROR = -1,
    OK = 0,
    RETRY = 1,
};

class GateKeeperResponse : public ::android::Parcelable {
  public:
    GateKeeperResponse() = default;
    GateKeeperResponse(GateKeeperResponse&&) = default;
    GateKeeperResponse(const GateKeeperResponse&) = default;
    GateKeeperResponse& operator=(GateKeeperResponse&&) = default;

    static GateKeeperResponse error() {
        return GateKeeperResponse(ResponseCode::ERROR);
    }
    static GateKeeperResponse retry(int32_t timeout) {
        return GateKeeperResponse(ResponseCode::RETRY, timeout);
    }
    static GateKeeperResponse ok(std::vector<uint8_t> payload,
                                 bool reenroll = false) {
        return GateKeeperResponse(ResponseCode::OK, 0, std::move(payload),
                                  reenroll);
    }

    status_t readFromParcel(const Parcel* in) override;
    status_t writeToParcel(Parcel* out) const override;

    const std::vector<uint8_t>& payload() const { return payload_; }
    ResponseCode response_code() const { return response_code_; }
    bool should_reenroll() const { return should_reenroll_; }
    int32_t timeout() const { return timeout_; }

  private:
    GateKeeperResponse(ResponseCode response_code, int32_t timeout = 0,
                       std::vector<uint8_t> payload = {},
                       bool should_reenroll = false)
        : response_code_(response_code),
          timeout_(timeout),
          payload_(std::move(payload)),
          should_reenroll_(should_reenroll) {}

    ResponseCode response_code_ = ResponseCode::ERROR;
    int32_t timeout_ = 0;
    std::vector<uint8_t> payload_;
    bool should_reenroll_ = false;
};

}  // namespace android::service::gatekeeper
