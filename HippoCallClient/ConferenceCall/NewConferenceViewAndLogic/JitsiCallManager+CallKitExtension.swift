//
//  JitsiCallManager+CallKitExtension.swift
//  HippoCallClient
//
//  Created by Arohi Sharma on 11/09/20.
//  Copyright © 2020 Vishal. All rights reserved.
//

import JitsiMeet
import WebRTC
import CallKit

extension JitsiCallManager : JMCallKitListener{
   
    func performAnswerCall(UUID: UUID, perform action: CXAnswerCallAction) {
        enableAudioSession()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.checkIfOfferIsSent { (status) in
                if status{
                    action.fulfill()
                }else{
                    action.fail()
                }
            }
        }
    }
    
//
    func performStartCall(UUID: UUID, isVideo: Bool) {
        isCallJoined = true
    }
    
    func performEndCall(UUID: UUID) {
        if activeCall?.isGroupCall ?? false{
            if self.isCallJoined{
                self.userDidTerminatedConference()
            }else{
                groupCallCancelled()
            }
        }else{
            if self.isCallJoined{
                // send call hungup if call is joined
                self.userDidTerminatedConference()
            }else{
                //send reject conference for call rejection
                self.sendCallRejected()
            }
        }
    }
    
    func providerDidActivateAudioSession(session: AVAudioSession){
       // RTCAudioSession.sharedInstance().audioSessionDidActivate(session)
    }
    
    func providerDidDeactivateAudioSession(session: AVAudioSession){
       // RTCAudioSession.sharedInstance().audioSessionDidDeactivate(session)
    }
    
    func providerTimedOutPerformingAction(action: CXAction){
        
    }
    
    func performSetMutedCall(UUID: UUID, isMuted: Bool){
//        let transaction = CXTransaction(action: CXSetMutedCallAction(call: UUID, muted: isMuted))
//        JMCallKitProxy.request(transaction) { (Error) in
//            
//        }
    }
    
    func providerDidReset() {
        
    }
}
extension JitsiCallManager{
    
    //end call from callkit
    
    func reportEndCallToCallKit(_ uid : String, _ reason : CXCallEndedReason){
        guard let uuid = UUID(uuidString: uid) else {
            return
        }
        JMCallKitProxy.reportCall(with: uuid, endedAt: nil, reason: reason)
    }
    
    
    func enableAudioSession(){
       // WebRTCClient.configureAudioSession()
//      let session = AVAudioSession.sharedInstance()
//        do{
//            try session.setCategory(.playAndRecord)
//            try session.setMode(.voiceChat)
//            try session.setActive(true)
//            try session.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
//        }catch {
//            print ("\(#file) - \(#function) error: \(error.localizedDescription)")
//        }
    }
}
