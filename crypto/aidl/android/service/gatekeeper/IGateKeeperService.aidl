/*
 * Copyright (C) 2015 The Android Open Source Project
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

package android.service.gatekeeper;

import android.service.gatekeeper.GateKeeperResponse;

@SensitiveData
interface IGateKeeperService {
    GateKeeperResponse enroll(int userId, in @nullable byte[] currentPasswordHandle,
            in @nullable byte[] currentPassword, in byte[] desiredPassword);

    GateKeeperResponse verify(int userId, in byte[] enrolledPasswordHandle,
            in byte[] providedPassword);

    GateKeeperResponse verifyChallenge(int userId, long challenge,
            in byte[] enrolledPasswordHandle, in byte[] providedPassword);

    long getSecureUserId(int userId);
    void clearSecureUserId(int userId);
    void reportDeviceSetupComplete();
}
