//
//  JitsiCallManager.swift
//  Fugu
//
//  Created by Rishi pal on 14/01/20.
//  Copyright © 2020 Fugu-Click Labs Pvt. Ltd. All rights reserved.
//

import Foundation
import UIKit
typealias VersionMismatchCallBack = ((_ versionMismatch: Bool) -> Void)
class JitsiCallManager {
    private(set) var activeCall: Call! {
        didSet{
            if activeCall == nil {
                print("active call nil")
            }
        }
    }
    static let shared = JitsiCallManager()
    var link: String!
    var repeatTimer: Timer?
    var repeatTimeriOS: Timer?
    var startConTimer: Timer?
    var timeSinceStartCon = 0
    var maxRepeatTime: Int = 60
    var timeElapsedSinceCallStart: Int = 0
    var timeElapsedSinceCallStartiOS: Int = 0
    var receivedCallData: [String : Any]?
    var isCallJoined: Bool = false
    private init() {}
    
    func startCall(with call: Call, completion: VersionMismatchCallBack? = nil) {
        timeElapsedSinceCallStart = 0
        activeCall = call
        link = createLink(for: call)
        addSignalReceiver()
        showDailCallView { (mismatch) in
            if completion != nil{
                completion!(mismatch)
            }
        }
    }
    
    func startReceivedCall(newCall: Call, signal: JitsiCallSignal) {
        
        if CallClient.shared.isUserBusy() { //, activeCall?.uID != newCall.uID user busy on another call
            sendBusy(with: activeCall, and: signal)
            return
        }
        
//        if activeCall == nil {
            activeCall = newCall
            link = activeCall?.inviteLink ?? ""
            addSignalReceiver()
//        }
        
//        startPublishingLocalNotificationForIncomingCallWith(signal: signal)
        sendReadyToConnect()
    }
    
    func handleMultipleDeviceCall(for data: [String: Any]) {
        guard let signalTypeRaw = data["video_call_type"] as? String,let  signalType = JitsiCallSignal.JitsiSignalType(rawValue:signalTypeRaw) else {
            return
        }
        
        if activeCall != nil, link == data["invite_link"] as? String, (signalType == .HUNGUP_CONFERENCE || signalType == .REJECT_CONFERENCE) {
            userDidCanceledDialCall()
        }
    }
}


//Received call
extension JitsiCallManager {
    
    func showReceivedCallView() {
        if let keyWindow = UIApplication.shared.keyWindow {
            if CallStartAndReceivedView.shared == nil {
                CallStartAndReceivedView.shared = CallStartAndReceivedView.loadView()
                CallStartAndReceivedView.shared.userInfo = userDataforDailCall()
                CallStartAndReceivedView.shared.receivedCallSetup()
                CallStartAndReceivedView.shared.delegate = self
                keyWindow.addSubview(CallStartAndReceivedView.shared)
                CallStartAndReceivedView.shared.playReceivedCallSound()
            }
        }
    }
    
    func showDailCallView(completion: VersionMismatchCallBack? = nil) {
        if let keyWindow = UIApplication.shared.keyWindow {
            if CallStartAndReceivedView.shared == nil {
                CallStartAndReceivedView.shared = CallStartAndReceivedView.loadView()
                CallStartAndReceivedView.shared.userInfo = userDataforDailCall()
                CallStartAndReceivedView.shared.dailCallSetup()
                CallStartAndReceivedView.shared.delegate = self
                keyWindow.addSubview(CallStartAndReceivedView.shared)
                CallStartAndReceivedView.shared.playDailCallSound()
                startTimerForConference(createCall: true)
                sendStartCallFirstTime(){ (mismatch) in
                    if completion != nil{
                        completion!(mismatch)
                    }
                }
                sendStartCallFirstTimeForiOS(){ (mismatch) in
                    if completion != nil{
                        completion!(mismatch)
                    }
                }
            }
        }
    }
    
    
    func userDataforDailCall()-> [String : Any] {
        var dict = [String : Any]()
        if activeCall == nil { return dict}
        dict["invite_link"] = link
        dict["muid"] = activeCall.uID
        dict["label"] = activeCall.peer.name
        
//        dict["user_id"] = activeCall.peer
        dict["user_thumbnail_image"] = activeCall.peer.image
        return dict
    }
}


//MARK: - Socket Signal
extension JitsiCallManager {
    
    func addSignalReceiver() {
        if activeCall != nil {
//            activeCall.signalingClient.signalReceivedFromPeer = nil // free the pervious
            activeCall?.signalingClient.signalReceivedFromPeer  = { [weak self] (jsonDict) in
                guard let signalTypeRaw = jsonDict["video_call_type"] as? String,let  signalType = JitsiCallSignal.JitsiSignalType(rawValue:signalTypeRaw) else {
                    return
                }
                let signal = JitsiCallSignal.getFrom(json: jsonDict)
                var  userId = jsonDict["user_id"] as? Int
                var deviceType = jsonDict["device_type"] as? Int ?? 0
                if userId == nil {
                    let strId = jsonDict["user_id"] as? String
                    if let someStrId = strId, let intId = Int(someStrId) {
                        userId = intId
                    }
                }
                
                guard signal?.senderDeviceID != CallClient.shared.currentDeviceID else {
                    return
                }
                
//                guard signal?.sender.peerId == self?.activeCall?.currentUser.peerId else {
//                    return
//                }
                
//                guard let senderId = userId , activeCall.currentUser.peerId != senderId  else {
//                    return
//                }
                
                switch signalType {
                case .START_CONFERENCE_IOS:
                    self?.sendReadyToConnect()
                break// nerver come on socket alway come from push
                case .START_CONFERENCE:
                break// nerver come on socket alway come from push
                case .READY_TO_CONNECT_CONFERENCE :
                    self?.endRepeatStartCall()
                    if (CallStartAndReceivedView.shared != nil){
                        CallStartAndReceivedView.shared.callStateText = "Ringing......"
                    }
                    self?.sendOffer()
                case .ANSWER_CONFERENCE:
//                    guard let activeSignal = self?.activeCall else {
//                        self?.removeDialAndReceivedView()
//                        return
//                    }
                    
                    guard signal?.sender.peerId != self?.activeCall.currentUser.peerId  else {
                        if signal?.senderDeviceID != CallClient.shared.currentDeviceID /*|| signal?.senderDeviceID == "" && deviceType == 3 )*/ {
                             self?.removeDialAndReceivedView()
                        } else {
                             self?.receivedAnswerFromOtherUser()
                            self?.removeStartConTimer(for: true, createCall: false)
                        }
                        return
                    }
                    
                    if (CallStartAndReceivedView.shared != nil) {
                        self?.receivedAnswerFromOtherUser()
                        self?.removeStartConTimer(for: true, createCall: false)
                    }
                    
                case .OFFER_CONFERENCE:
                    self?.showReceivedCallView()
                case .REJECT_CONFERENCE:
                    self?.receivedRejectCallFromOtherUser()
                case .HUNGUP_CONFERENCE:
                    self?.otherUserCallHungup()
                case .USER_BUSY_CONFERENCE:
                    self?.otherUserBusyOnOtherCall()
                case .READY_TO_CONNECT_CONFERENCE_IOS:
                    self?.endRepeatStartCalliOS()
                    if (CallStartAndReceivedView.shared != nil){
                        CallStartAndReceivedView.shared.callStateText = "Ringing......"
                    }
                    self?.sendOffer()
                    break
                }
            }
        }
    }
    
    func startTimerForConference(createCall: Bool){
        if (activeCall != nil && startConTimer == nil){
            startConTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateStartConTimer(_:)), userInfo: nil, repeats: true)
        } else {
            removeStartConTimer(for: false, createCall: false)
        }
    }
    
    @objc func updateStartConTimer(_ createCall: Bool){
        timeSinceStartCon += 1
        if timeSinceStartCon == 60 {
            removeStartConTimer(for: false, createCall: createCall)
        }
    }
    func removeStartConTimer(for answer: Bool, createCall: Bool){
        startConTimer?.invalidate()
        startConTimer = nil
        timeSinceStartCon = 0
        if createCall {
            userDidCanceledDialCall()
            return
        }
        if (!answer){
            removeDialAndReceivedView()
            resetAllResourceForNewCall()
        }
    }
    
    func sendData(dict: [String : Any], completion: VersionMismatchCallBack? = nil) {
        //Logger.shared.printVar(for: dict)
        activeCall?.signalingClient.connectClient(completion: { (success) in
            self.activeCall.signalingClient.sendJitsiObject(json: dict) { [weak self] (mark, error) in
                if !mark{
                   // Logger.shared.printVar(for: error?.localizedDescription)
                    if (error?.code == 415){
                        self?.removeDialAndReceivedView()
                        self?.removeStartConTimer(for: false, createCall: true)
                        self?.resetAllResourceForNewCall()
                        completion?(true)
                    }
                }
            }
        })
    }
    
    func sendStartCallFirstTime(completion: VersionMismatchCallBack? = nil) {
        let signal = JitsiCallSignal(signalType: .START_CONFERENCE, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: false)
        let dict = signal.getJsonToSendToFaye()
        sendData(dict: dict) { (mismatch) in
            if completion != nil{
                completion!(mismatch)
            }
        }
        
        if repeatTimer == nil {
            repeatTimer =  Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { [weak self]_ in
                //Logger.shared.printVar(for: "timer")
                self?.timeElapsedSinceCallStart += 5
                self?.sendRepeatStartCall()
            })
        }
    }
    
    func sendStartCallFirstTimeForiOS(completion: VersionMismatchCallBack? = nil) {
        let signal = JitsiCallSignal(signalType: .START_CONFERENCE_IOS, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: false /*true*/)
        let dict = signal.getJsonToSendToFaye()
        sendData(dict: dict) { (mismatch) in
            if completion != nil{
                completion!(mismatch)
            }
        }
        
        if repeatTimeriOS == nil {
            repeatTimeriOS =  Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { [weak self]_ in
                //Logger.shared.printVar(for: "timer")
                self?.timeElapsedSinceCallStartiOS += 5
                self?.sendRepeatStartCalliOS()
            })
        }
    }
    
    func sendRepeatStartCalliOS() {
        if maxRepeatTime > timeElapsedSinceCallStartiOS, activeCall != nil { // send repeat call
            let signal = JitsiCallSignal(signalType: .START_CONFERENCE_IOS, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true)
            let dict = signal.getJsonToSendToFaye()
            sendData(dict: dict)
        }else {
            // remove
            //Logger.shared.printVar(for: "timer over")
//            userDidCanceledDialCall()
        }
    }
    
    func sendRepeatStartCall() {
        if maxRepeatTime > timeElapsedSinceCallStart, activeCall != nil { // send repeat call
            let signal = JitsiCallSignal(signalType: .START_CONFERENCE, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true)
            let dict = signal.getJsonToSendToFaye()
            sendData(dict: dict)
        }else { // remove
            //Logger.shared.printVar(for: "timer over")
//            userDidCanceledDialCall()
        }
    }
    
    func endRepeatStartCall() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
    
    func endRepeatStartCalliOS(){
        repeatTimeriOS?.invalidate()
        repeatTimeriOS = nil
    }
    
    func sendOffer() {
        if activeCall == nil {
            return
        }
        let signal = JitsiCallSignal(signalType: .OFFER_CONFERENCE, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true)
        let dict = signal.getJsonToSendToFaye()
        sendData(dict: dict)
    }
    
    func sendReadyToConnect() {
        if activeCall == nil {
            return
        }
        if (activeCall.isCallByMe){
            return
        }
        let signal = JitsiCallSignal(signalType: .READY_TO_CONNECT_CONFERENCE_IOS, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true)
        let dict = signal.getJsonToSendToFaye()
        sendData(dict: dict)
        startTimerForConference(createCall: false)
    }
    
    
    func sendAnswered() {
        if activeCall == nil {
            return
        }
        let signal = JitsiCallSignal(signalType: .ANSWER_CONFERENCE, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true)
        let dict = signal.getJsonToSendToFaye()
        sendData(dict: dict)
        self.removeStartConTimer(for: true, createCall: false)
    }
    
    func sendCallRejected() {
        if activeCall == nil {
            return
        }
        let signal = JitsiCallSignal(signalType: .REJECT_CONFERENCE, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true)
        let dict = signal.getJsonToSendToFaye()
        sendData(dict: dict)
        callRejectByCurrentUser()
    }
    
    
    func sendBusy(with otherCall: Call, and signal: JitsiCallSignal) {
        let signal = JitsiCallSignal(signalType: .USER_BUSY_CONFERENCE, callUID: otherCall.uID, sender: otherCall.currentUser, senderDeviceID: otherCall.uID , callType: otherCall.type , link: signal.conferenceLink ?? "", isFSilent: true)
        let dict = signal.getJsonToSendToFaye()
        otherCall.signalingClient.sendJitsiObject(json: dict) { (mark, error) in}
    }
    
    func otherUserCallHungup() {
        if isCallJoined {
            JitsiConfrenceCallView.shared.leaveConfrence { [weak self](mark) in
                if mark {
                    if JitsiConfrenceCallView.shared  == nil { return }
                    JitsiConfrenceCallView.shared.removeFromSuperview()
                    JitsiConfrenceCallView.shared.delegate = nil
                    JitsiConfrenceCallView.shared = nil
                    self?.resetAllResourceForNewCall()
                }
            }
        }else {
            removeDialAndReceivedView()
            resetAllResourceForNewCall()
        }
        self.removeStartConTimer(for: false, createCall: false)
    }
    
    func sendCallHungup() {
        if activeCall != nil {
            let signal = JitsiCallSignal(signalType: .HUNGUP_CONFERENCE, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true)
            let dict = signal.getJsonToSendToFaye()
            sendData(dict: dict)
        }
        if JitsiConfrenceCallView.shared != nil {
            JitsiConfrenceCallView.shared.removeFromSuperview()
            JitsiConfrenceCallView.shared.delegate = nil
            JitsiConfrenceCallView.shared = nil
        }
        
        resetAllResourceForNewCall()
    }
    
    func otherUserBusyOnOtherCall() {
        endRepeatStartCalliOS()
        endRepeatStartCall()
        resetAndShowBusy(with: "User busy with another call")
    }
}

extension JitsiCallManager : CallStartAndReceivedViewDelegate {
    func userDidCanceledDialCall() {
        if activeCall != nil {
            let signal = JitsiCallSignal(signalType: .HUNGUP_CONFERENCE, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true)
            let dict = signal.getJsonToSendToFaye()
            sendData(dict: dict)
        }
        removeDialAndReceivedView()
        resetAllResourceForNewCall()
    }
    
    func userDidAnswered() {
        sendAnswered()
        receivedAnswerFromOtherUser()
    }
    
    func userDidCanceled() {
        sendCallRejected()
    }
}




//MARK: -Jitsi Meet View Logic

extension JitsiCallManager {
    
    func receivedAnswerFromOtherUser() {
        showJitsiView()
    }
    
    func receivedRejectCallFromOtherUser() {
        resetAndShowBusy(with: "Call Declined")
    }
    
    func removeDialAndReceivedView() {
        if CallStartAndReceivedView.shared != nil {
            CallStartAndReceivedView.shared.remove()
        }
        
    }
    
    func showJitsiView() {
        if let keyWindow = UIApplication.shared.keyWindow {
            if JitsiConfrenceCallView.shared == nil && activeCall != nil {
                //signal?.senderDeviceID != CallClient.shared.currentDeviceID
                let model = userDataForOutgoingCall()
                JitsiConfrenceCallView.shared = JitsiConfrenceCallView.loadView(with: keyWindow.frame)
                JitsiConfrenceCallView.shared.setupJitsi(for: model)
                JitsiConfrenceCallView.shared.delegate = self
                keyWindow.addSubview(JitsiConfrenceCallView.shared)
            }
        }
        removeDialAndReceivedView()
    }
    
    func userDataForOutgoingCall() -> JitsiMeetDataModel {
        let userName = activeCall.currentUser.name
        let email = ""
        let imageURL = URL(string: activeCall.currentUser.image)
        let audioOnly = activeCall.type == .audio ? true : false
        let tempLink = getLinkAfertRemoveAudio(link: link)
        let data = getURLOrRoomId(for: tempLink)
        //Logger.shared.printVar(for: data.url.absoluteString)
        print("tempLink is", tempLink, data.url)
        let userModel = JitsiMeetDataModel(userName: userName, userEmail: email, userImage: imageURL, audioOnly: audioOnly, serverURl: data.url, roomID: data.roomId)
        return userModel
    }
    
    func resetAllResourceForNewCall() {
        activeCall = nil
        link = nil
        repeatTimer = nil
        repeatTimeriOS = nil
        startConTimer?.invalidate()
        startConTimer = nil
        timeSinceStartCon = 0
        timeElapsedSinceCallStart = 0
        timeElapsedSinceCallStartiOS = 0
        receivedCallData = nil
        isCallJoined = false
    }
    
    func showBusyView(with message: String) {
        if CallStartAndReceivedView.shared == nil {return}
        CallStartAndReceivedView.shared.showUserBusy(With: message) { [weak self] (mark) in
            self?.removeDialAndReceivedView()
        }
    }
    
    func callRejectByCurrentUser(){
        resetAllResourceForNewCall()
        removeDialAndReceivedView()
    }
    
    func resetAndShowBusy(with message: String) {
        resetAllResourceForNewCall()
        showBusyView(with: message)
    }
    
}


//MARK: - Jitsi URL Logic

extension JitsiCallManager {
    
    func createLink(for call: Call)-> String {
        let url = JitsiConstants.inviteLink
        let randomStr = randomString(length: 11) + "iOS"
        var link = url + randomStr
        if call.type == .audio {
            link += "#config.startWithVideoMuted=true"
        }
        return link
    }
    
    func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }

    
    
    func getLinkAfertRemoveAudio(link: String) -> String {
        let link = link.components(separatedBy: "#").first!
        return link
    }
    
    func getURLOrRoomId(for link: String) -> (url: URL , roomId: String) {
        let roomId = (link as NSString).lastPathComponent
        //Logger.shared.printVar(for: roomId)
        let roomIdRemovedLink = link.replacingOccurrences(of: roomId, with: "")
        //Logger.shared.printVar(for: roomIdRemovedLink)
        let remainLink = link.replacingOccurrences(of: "/\(roomId)", with: "")
        //Logger.shared.printVar(for: remainLink)
        let serverURL = URL(string: remainLink)!
        return (serverURL , roomId)
    }
    
//    func showFeedbackPopup(for callType: Call.CallType) {
//        if FuguCallFeedbackManager.share == nil {
//            FuguCallFeedbackManager.share = FuguCallFeedbackManager()
//            let feedbackType = callType == .audio ? CallFeedbackType.audioCall : CallFeedbackType.videoCall
//            FuguCallFeedbackManager.share.showFeedbackPopup(for: feedbackType)
//        }
//    }
    
    
    func sendSignalWith(json: [String: Any], completion: VersionMismatchCallBack? = nil) {
        activeCall?.signalingClient.connectClient(completion: { [weak self]  (success) in
            self?.activeCall?.signalingClient.sendJitsiObject(json: json, completion: {(success, error) in
                
                if !success{
                   // Logger.shared.printVar(for: error?.localizedDescription)
                    if (error?.code == 415){
                        self?.removeDialAndReceivedView()
                        self?.removeStartConTimer(for: false, createCall: true)
                        self?.resetAllResourceForNewCall()
                        completion?(true)
                    }
                }
            })
        })
    }
}



extension JitsiCallManager : JitsiConfrenceCallViewDelegate  {
    func userDidJoinConference() {
        isCallJoined = true
    }
    
    func userWillLeaveConference() {
        
    }
    
    func userDidTerminatedConference() {
        sendCallHungup()
    }
    
    func userDidEnterPictureInPicture() {
        
    }
    
    
}




//func changeAudioRouteToSpeaker(_ isSwitching: Bool, completion: @escaping (Bool) -> Void) {
//
//   let newOveride = isSwitching ? AVAudioSessionPortOverride.speaker : AVAudioSessionPortOverride.none
//
//   if currentAudioOveride == newOveride {
//      completion(true)
//      return
//   }
//
//   RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
//      let session = RTCAudioSession.sharedInstance()
//      session.lockForConfiguration()
//      do {
//         try RTCAudioSession.sharedInstance().overrideOutputAudioPort(newOveride)
//         self.currentAudioOveride = newOveride
//         RTCDispatcher.dispatchAsync(on: .typeMain, block: {
//            completion(true)
//         })
//
//      } catch {
//         print(error.localizedDescription)
//         RTCDispatcher.dispatchAsync(on: .typeMain, block: {
//            completion(false)
//         })
//      }
//      session.unlockForConfiguration()
//   }
//}
