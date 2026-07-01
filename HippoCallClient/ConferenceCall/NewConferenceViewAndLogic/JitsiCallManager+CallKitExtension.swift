//
//  JitsiCallManager+CallKitExtension.swift
//  HippoCallClient
//
//  Created by Arohi Sharma on 11/09/20.
//  Copyright © 2020 Vishal. All rights reserved.
//

import JitsiMeetSDK
import WebRTC
import CallKit
import os.log

private let ckLog = OSLog(subsystem: "com.hippo.callclient", category: "CallKit")

extension JitsiCallManager : JMCallKitListener{


    @objc(providerDidReset)
    func providerDidReset() {
        os_log("[CallKit] providerDidReset", log: ckLog, type: .error)
    }

    @objc(performAnswerCallWithUUID:)
    func performAnswerCall(with uuid: UUID) {
        os_log("[CallKit] performAnswerCall — uuid=%{public}@, isCallJoined=%{public}@, inProgress=%{public}@",
               log: ckLog, type: .default, uuid.uuidString, "\(isCallJoined)", "\(isAnswerFlowInProgress)")
        // Guard: CallKit can fire performAnswerCall multiple times (e.g. when the active
        // audio session state changes). Each call restarts checkIfOfferIsSent which queues
        // another answer flow. Multiple flows → multiple showJitsiView calls → receiver
        // appears in the Jitsi room more than once (from the caller's perspective).
        guard !isAnswerFlowInProgress else {
            os_log("[CallKit] performAnswerCall — IGNORED (answer flow already in progress)", log: ckLog, type: .default)
            return
        }
        isAnswerFlowInProgress = true
        self.checkIfOfferIsSent { status in
            os_log("[CallKit] checkIfOfferIsSent result=%{public}@", log: ckLog, type: .default, "\(status)")
            if status {
                // logic for fulfilling action
            }
        }
    }


    @objc(performEndCallWithUUID:)
    func performEndCall(with uuid: UUID) {
        os_log("[CallKit] performEndCall (X button) — uuid=%{public}@, isCallJoined=%{public}@, isGroupCall=%{public}@",
               log: ckLog, type: .default, uuid.uuidString, "\(isCallJoined)", "\(activeCall?.isGroupCall ?? false)")
        if activeCall?.isGroupCall ?? false {
            if self.isCallJoined {
                os_log("[CallKit] → userDidTerminatedConference (group, joined)", log: ckLog, type: .default)
                self.userDidTerminatedConference()
            } else {
                os_log("[CallKit] → groupCallCancelled (group, not joined)", log: ckLog, type: .default)
                groupCallCancelled()
            }
        } else {
            if self.isCallJoined {
                os_log("[CallKit] → userDidTerminatedConference (1:1, joined)", log: ckLog, type: .default)
                self.userDidTerminatedConference()
            } else {
                os_log("[CallKit] → sendCallRejected (1:1, not yet joined)", log: ckLog, type: .default)
                self.sendCallRejected()
            }
        }
    }

    @objc(performSetMutedCallWithUUID:isMuted:)
    func performSetMutedCall(with uuid: UUID, isMuted muted: Bool) {
        os_log("[CallKit] performSetMutedCall — isMuted=%{public}@", log: ckLog, type: .default, "\(muted)")
    }

    @objc(performStartCallWithUUID:isVideo:)
    func performStartCall(with uuid: UUID, isVideo: Bool) {
        os_log("[CallKit] performStartCall — isVideo=%{public}@", log: ckLog, type: .default, "\(isVideo)")
    }

    @objc(providerDidActivateAudioSessionWithSession:)
    func providerDidActivateAudioSession(with session: AVAudioSession) {
        os_log("[CallKit] providerDidActivateAudioSession — category=%{public}@, mode=%{public}@",
               log: ckLog, type: .default, session.category.rawValue, session.mode.rawValue)
        // useManualAudio = true tells WebRTC to wait for audioSessionDidActivate before
        // starting the audio unit. Without this, WebRTC auto-mode can race with CallKit's
        // audio activation and fail to start the microphone capture (input) bus.
        // This is process-global via RTCAudioSession.sharedInstance() and applies to both
        // P2P WebRTC calls and Jitsi's bundled WebRTC (same Obj-C singleton).
        RTCAudioSession.sharedInstance().useManualAudio = true
        RTCAudioSession.sharedInstance().audioSessionDidActivate(session)
        RTCAudioSession.sharedInstance().isAudioEnabled = true
    }

    @objc(providerDidDeactivateAudioSessionWithSession:)
    func providerDidDeactivateAudioSession(with session: AVAudioSession) {
        os_log("[CallKit] providerDidDeactivateAudioSession", log: ckLog, type: .default)
        RTCAudioSession.sharedInstance().audioSessionDidDeactivate(session)
        RTCAudioSession.sharedInstance().isAudioEnabled = false
    }

    @objc(providerTimedOutPerformingActionWithAction:)
    func providerTimedOutPerformingAction(with action: CXAction) {
        os_log("[CallKit] providerTimedOut — action=%{public}@", log: ckLog, type: .error, "\(type(of: action))")
        action.fulfill()
    }

    // End call from callkit
    func reportEndCallToCallKit(_ uid: String, _ reason: CXCallEndedReason) {
        os_log("[CallKit] reportEndCallToCallKit — uid=%{public}@, reason=%{public}d",
               log: ckLog, type: .default, uid, reason.rawValue)
        guard let uuid = UUID(uuidString: uid) else {
            os_log("[CallKit] reportEndCallToCallKit — INVALID uid, cannot create UUID", log: ckLog, type: .error)
            return
        }
        JMCallKitProxy.reportCall(with: uuid, endedAt: nil, reason: reason)
    }


}
