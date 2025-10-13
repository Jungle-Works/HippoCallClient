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

extension JitsiCallManager : JMCallKitListener{
   
    @objc(performStartCallWithUUID:isVideo:)
       func performStartCall(with uuid: UUID, isVideo: Bool) {
           print("Start call with UUID: \(uuid), isVideo: \(isVideo)")
           // Your existing start call logic
       }

    @objc(performAnswerCallWithUUID:)
      func performAnswerCall(with uuid: UUID) {
          self.checkIfOfferIsSent { status in
              if status {
                  // logic for fulfilling action
              }
          }
      }
    
    @objc(performEndCallWithUUID:)
        func performEndCall(with uuid: UUID) {
            if activeCall?.isGroupCall ?? false {
                if self.isCallJoined {
                    self.userDidTerminatedConference()
                } else {
                    groupCallCancelled()
                }
            } else {
                if self.isCallJoined {
                    self.userDidTerminatedConference()
                } else {
                    self.sendCallRejected()
                }
            }
        }
    
    //end call from callkit
    func reportEndCallToCallKit(_ uid : String, _ reason : CXCallEndedReason){
        guard let uuid = UUID(uuidString: uid) else {
            return
        }
        JMCallKitProxy.reportCall(with: uuid, endedAt: nil, reason: reason)
    }
    
    @objc(providerDidActivateAudioSessionWithSession:)
      func providerDidActivateAudioSession(with session: AVAudioSession) {
          print("Audio session activated")
          RTCAudioSession.sharedInstance().audioSessionDidActivate(session)
          RTCAudioSession.sharedInstance().isAudioEnabled = true
      }

      @objc(providerDidDeactivateAudioSessionWithSession:)
      func providerDidDeactivateAudioSession(with session: AVAudioSession) {
          print("Audio session deactivated")
          RTCAudioSession.sharedInstance().audioSessionDidDeactivate(session)
          RTCAudioSession.sharedInstance().isAudioEnabled = false
      }

      @objc(providerDidReset)
      func providerDidReset() {
          print("Stop Audio ==STOP-AUDIO==")
      }
}
