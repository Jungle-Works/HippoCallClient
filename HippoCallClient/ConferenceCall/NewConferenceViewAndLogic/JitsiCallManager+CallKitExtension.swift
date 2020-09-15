//
//  JitsiCallManager+CallKitExtension.swift
//  HippoCallClient
//
//  Created by Arohi Sharma on 11/09/20.
//  Copyright © 2020 Vishal. All rights reserved.
//

import JitsiMeet

import CallKit
import WebRTC

extension JitsiCallManager : JMCallKitListener{
   
    func performAnswerCall(UUID: UUID) {
        self.userDidAnswered()
    }
    
    func performStartCall(UUID: UUID, isVideo: Bool) {
        isCallJoined = true
    }
    
    func performEndCall(UUID: UUID) {
        if self.isCallJoined{
            // send call hungup if call is joined
          self.userDidTerminatedConference()
        }else{
            //send reject conference for call rejection
          self.sendCallRejected()
        }
    }
    
    func providerDidActivateAudioSession(session: AVAudioSession){
         RTCAudioSession.sharedInstance().audioSessionDidActivate(session)
    }
    
    func providerDidDeactivateAudioSession(session: AVAudioSession){
        RTCAudioSession.sharedInstance().audioSessionDidDeactivate(session)
    }
    
    func providerTimedOutPerformingAction(action: CXAction){
        
    }
    
    func performSetMutedCall(UUID: UUID, isMuted: Bool){
        
    }
    
    func providerDidReset() {
        
    }
}
extension JitsiCallManager{
    
    //end call from callkit
    
    func reportEndCallToCallKit(_ uid : String){
        guard let uuid = UUID(uuidString: uid) else {
            return
        }
        JMCallKitProxy.reportCall(with: uuid, endedAt: nil, reason: .declinedElsewhere)
    }
    
}
