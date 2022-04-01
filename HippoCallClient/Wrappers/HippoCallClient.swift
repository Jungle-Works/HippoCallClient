//
//  HippoCallClient.swift
//  HippoCallClient
//
//  Created by Vishal on 14/11/18.
//  Copyright © 2018 Vishal. All rights reserved.
//

import Foundation
import CallKit


public class HippoCallClient {
   public static let shared = HippoCallClient()
   private(set) var delgate: HippoCallClientDelegate?
   
    
    /// This variable will send ongoing call uuid if any
    public var activeCallUUID: String? {
        return CallClient.shared.activeCall?.uID
    }
   
    /// set the delegate to communicate with callClient
    ///
    /// - Parameter delegate: Class that inherted protocol HippoCallClientDelegate
    public func registerHippoCallClient(delegate: HippoCallClientDelegate) {
        self.delgate = delegate
//        JitsiCallManager.shared.isCallStarted = {(status) in
//            delegate.callStarted(isCallStarted: status)
//        }
    }
    
    func createShareUrl(from url : String) {
        delgate?.shareUrlApiCall(url: url)
    }
    
    
    /// This function is public and called when ever you recieve a voip Notification
    ///
    /// - Parameters:
    ///   - dictionary: voip Payload
    ///   - peer: Information of caller who had called you
    ///   - signalingClient: Class that satisfy SignalingClient Protocol, and this class is used for your signaling
    ///   - currentUser: Information of current user in your app
    public func voipNotificationRecieved(dictionary: [AnyHashable: Any], peer: CallPeer, signalingClient: SignalingClient, currentUser: CallPeer,isInviteEnabled: Bool) {
        CallClient.shared.voipNotificationReceived(dictionary: dictionary, peer: peer, signalingClient: signalingClient, currentUser: currentUser,isInviteEnabled: isInviteEnabled)
    }
    
    public func voipNotificationRecievedForGroupCall(dictionary: [AnyHashable: Any], peer: CallPeer, signalingClient: SignalingClient, currentUser: CallPeer,isInviteEnabled: Bool) {
        CallClient.shared.voipNotificationRecievedForGroupCall(dictionary: dictionary, peer: peer, signalingClient: signalingClient, currentUser: currentUser, isInviteEnabled: isInviteEnabled)
    }
    
    public func appSecretkeyFromCallManager(key: String, agentToken: String, userType: userType){
        CallClient.shared.appSecretFromHippoCallClient(key: key, agentToken: agentToken, userType: userType)
    }
    
    
    /// This is function is called to hangup current ongoing call if any
    public func hangupCall() {
        CallClient.shared.hangupCall()
    }
    
    public func terminateSessionIfAny(){
//        JitsiCallManager.shared.leaveConferenceOnForceKill()
    }
    
    public func keyWindowChangedFromParent(){
//        JitsiCallManager.shared.keyWindowChanged()
    }
    
    public func actionFromCallKit(isAnswered: Bool, completion: @escaping (Bool) -> Void){
        if isAnswered{
            JitsiCallManager.shared.checkIfOfferIsSent { (status) in
                completion(status)
            }
        }else{
            if JitsiCallManager.shared.activeCall?.isGroupCall ?? false{
                if JitsiCallManager.shared.isCallJoined{
                    JitsiCallManager.shared.userDidTerminatedConference()
                }else{
                    JitsiCallManager.shared.groupCallCancelled()
                }
            }else{
                if JitsiCallManager.shared.isCallJoined{
                    // send call hungup if call is joined
                    JitsiCallManager.shared.userDidTerminatedConference()
                }else{
                    //send reject conference for call rejection
                    JitsiCallManager.shared.sendCallRejected()
                }
            }
        }
    }
    
    public func updateProviderInJitsi(with provider: CXProvider){
        guard JitsiCallManager.shared.provider != nil else {
            JitsiCallManager.shared.provider = provider
            return
        }
    }
    
    /// This function is used to start call
    ///
    /// - Parameters:
    ///   - call: Call object that contain information about call
    ///   - completion: Callback that provide status whether the call is made or not
    public func startCall(call: Call,isInviteEnabled: Bool, completion: @escaping (Bool) -> Void) {
        JitsiCallManager.shared.startCall(with: call, isInviteEnabled: isInviteEnabled) { (versionMismatch) in
            if versionMismatch {
                CallClient.shared.startNew(call: call, completion: completion)
            }
        }
    }
    
    public func startGroupCall(call: Call, groupCallData: CallClientGroupCallData){
        JitsiCallManager.shared.startGroupCall(with: call, with: groupCallData)
    }
  
    public func joinCallLink(customerName: String, customerImage: String, url: String, isInviteEnabled: Bool,callType:String) {
        JitsiCallManager.shared.joinCallLink(customerName: customerName, customerImage: customerImage, url: url, isInviteEnabled: isInviteEnabled, callType: callType)
    }
    
    public func checkIfUserIsBusy(newCallUID: String) -> Bool {
        return JitsiCallManager.shared.checkIfUserIsBusy(newCallUID: newCallUID)
//        return false
    }
    
    public func startCall(call: Call, isInviteEnabled: Bool, completion: @escaping (Bool, NSError?) -> Void) {
        
//        HippoCallClientUrl.shared.id = Int(call.currentUser.peerId)
//        HippoCallClientUrl.shared.enUserId = call.currentUser.enUserId
        HippoCallClientUrl.shared.userName = call.peer.name
        
        if JitsiCallManager.shared.callingType == 3{                            //VIDEO SDK CALL
            
            if !(call.transactionId?.isEmpty ?? true){
                JitsiCallManager.shared.jitsiUrl = call.transactionId!
            }
            
            CallClient.shared.getVideoSdkTokenNative() { meetId in
                
                JitsiCallManager.shared.callTypeForIncomingCall = call.type
                
                JitsiCallManager.shared.startCall(with: call, isInviteEnabled: isInviteEnabled, meetingId: meetId) { (versionMismatch) in
                    
                    if versionMismatch {
                        let info = [NSLocalizedDescriptionKey:"Calling failed due to verison mismatch."];
                        let versionMismatchError = NSError(domain: "error.hippo", code: 415, userInfo: info)
                        completion(false,versionMismatchError)
                    }
                    else {
                        completion(true,nil)
                    }
                }
            }
        }else{
            JitsiCallManager.shared.startCall(with: call, isInviteEnabled: isInviteEnabled) { (versionMismatch) in
                if versionMismatch {
                    let info = [NSLocalizedDescriptionKey:"Calling failed due to verison mismatch."];
                    let versionMismatchError = NSError(domain: "error.hippo", code: 415, userInfo: info)
                    completion(false,versionMismatchError)
                }
                else {
                    completion(true,nil)
                }
            }
        }
    }
    
    public func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    public func startWebRTCCall(call:Call, completion: @escaping (Bool) -> Void) {
        
        CallClient.shared.startNew(call: call, completion: completion)
    }
    
    
    /// This function is add on just to show Connecting status no actual call is made here
    ///
    /// - Parameters:
    ///   - call: Request param
    ///   - uuid: Call UUID
    public func startConnecting(call: PresentCallRequest, uuid: String) {
        JitsiCallManager.shared.showConnectingView()
    }
    
    /// This function is requried to be full filled as it will set credentials for turn and stun server.
    ///
    /// let ice_servers: [String: Any] = [
    /// "stun": ["stun:turnserver.example.com:<PORT>"],
    /// "turn":  [
    ///     "turn:turnserver.example.com:<PORT>?transport=UDP",
    ///     "turn:turnserver.example.com:<PORT>?transport=TCP",
    ///     "turns:turnserver.example.com:<PORT>?transport=UDP",
    ///     "turns:turnserver.example.com:<PORT>?transport=TCP"
    ///  ]]
    /// let json: [String: Any] =  ["credential": "<Credential>",
    ///                            "username": "<User_name>",
    ///                            "ice_servers": ice_servers,
    ///                            "turn_api_key": <turn server api key>]
    ///
    /// - Parameter rawCredentials: raw data of stun and turn server.
    public func setCredentials(rawCredentials: [String: Any]) {
        CallClient.shared.setCredentials(rawCredentials: rawCredentials)
    }
    
    public func hideViewInPip(){
        JitsiCallManager.shared.hideJitsiView()
    }
    
    public func unHideViewInPip(){
        JitsiCallManager.shared.unHideJitsiView()
    }
    
}
