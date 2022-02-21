//
//  JitsiCallManager.swift
//  Fugu
//
//  Created by Rishi pal on 14/01/20.
//  Copyright © 2020 Fugu-Click Labs Pvt. Ltd. All rights reserved.
//

import Foundation
import UIKit
import CallKit
import AVFoundation
import JitsiMeetSDK


typealias VersionMismatchCallBack = ((_ versionMismatch: Bool) -> Void)

class JitsiCallManager : NSObject{
    private(set) var activeCall: Call! {
        didSet{
            if activeCall == nil {
                print("active call nil")
            }else{
                print("active call setup")
            }
        }
    }
    
    static let shared = JitsiCallManager()
    //    var callStartAndRecieveView = CallStartAndReceivedView()
    var link: String!
    var repeatTimer : Timer?
    var repeatTimeriOS : Timer?
    var startConTimer : Timer?
    var repeatGroupCallTimer : Timer?
    var repeatShowingPopupTimer : Timer?
    var timeSinceStartCon = 0
    var maxRepeatTime: Int = 60
    var timeElapsedSinceCallStart: Int = 0
    var timeElapsedSinceCallStartiOS: Int = 0
    var timeElapsedSinceGroupCallStart : Int = 0
    var timeElapsedSincePopupShown : Int = 0
    var receivedCallData: [String : Any]?
    var isCallJoined: Bool = false
    var muidDic : [String : Bool]?
    var muidOne2oneDic : [String : Bool]?
    var transactionID : String?
    var jitsiUrl : String?
    var userBusy_Muid : String?
    var isCallStarted : ((Bool)->())?
    var isOfferRecieved : Bool?
    var timeElapsedSinceWaitingForOffer = 0
    var isCallJoinedFromLink: Bool = false
    var isInviteEnabled: Bool = false
    var callingType = UserDefaults.standard.value(forKey: "callingType") as? Int            //2 for jitsi, 3 for videosdk
    var idForHungUpSent: String? = nil
    
    
    private override init() {
        super.init()
        
        if !(JMCallKitProxy.isProviderConfigured()){
            JMCallKitProxy.configureProvider(localizedName: "", ringtoneSound: nil, iconTemplateImageData: nil)
        }
        JMCallKitProxy.addListener(self)
    }
    
    func startCall(with call: Call,isInviteEnabled: Bool, meetingId: String? = "", completion: VersionMismatchCallBack? = nil) {
        
        var finalMeetId : String!
        
        if let meetId = meetingId, !meetId.isEmpty{
            finalMeetId = meetId
        }else{
            finalMeetId = randomString(length: 8)
        }
        
        
        if !(call.transactionId?.isEmpty ?? true){
            finalMeetId = call.transactionId!
        }
        
//        CallClient.shared.fullName = call.peer.name
        JitsiCallManager.shared.jitsiUrl = finalMeetId
        
        
        if isCallJoinedFromLink {
            return
        }
        
        self.isInviteEnabled = isInviteEnabled
        timeElapsedSinceCallStart = 0
        activeCall = call
        
        let links = createLink(for: call)
        link = links.0
        jitsiUrl = links.1
        addSignalReceiver()
        removeConnectingView()
        
        DispatchQueue.main.async {
            self.showDailCallView { (mismatch) in
                if completion != nil{
                    completion!(mismatch)
                }
            }
        }
    }
    
    func checkIfUserIsBusy(newCallUID: String) -> Bool {
        if (activeCall != nil && newCallUID != activeCall?.uID) { //, activeCall?.uID != newCall.uID user busy on another call
            return true
        }else if isCallJoinedFromLink {
            return true
        }else {
            return false
        }
    }
    
    
    func startReceivedCall(newCall: Call, signal: JitsiCallSignal, isInviteEnabled: Bool) {
        
        if muidOne2oneDic?.keys.first == newCall.uID, muidOne2oneDic?[newCall.uID] == true{
            return
        }
        
        if checkIfUserIsBusy(newCallUID: newCall.uID) {
            sendBusy(with: newCall, and: signal)
            return
        }
        
        // MARK: - Just added this check because android was sendng events even after sending hung up or reject conference
        if newCall.uID == idForHungUpSent{
            return
        }
        
        if RecievedGroupCallView.shared != nil || JitsiConfrenceCallView.shared != nil || CallStartAndReceivedView.shared != nil{
            return
        }
        self.isInviteEnabled = isInviteEnabled
        activeCall = newCall
        link = activeCall?.inviteLink ?? ""
        jitsiUrl = activeCall?.jitsiUrl ?? ""
        addSignalReceiver()
        sendReadyToConnect()
    }
    
    func joinCallLink(customerName: String, customerImage: String, url: String, isInviteEnabled: Bool,callType: String) {
        self.link = url
        self.jitsiUrl = url
        self.showJitsiViewToJoinLink(customerName: customerName, customerImage: customerImage, url: url, isInviteEnabled: isInviteEnabled)
        isCallJoinedFromLink = true
    }
    
    
    //    func handleMultipleDeviceCall(for data: [String: Any]) {
    //        guard let signalTypeRaw = data["video_call_type"] as? String,let  signalType = JitsiCallSignal.JitsiSignalType(rawValue:signalTypeRaw) else {
    //            return
    //        }
    //
    //        if activeCall != nil, link == data["invite_link"] as? String, (signalType == .HUNGUP_CONFERENCE || signalType == .REJECT_CONFERENCE) {
    //            userDidCanceledDialCall()
    //        }
    //    }
}

extension JitsiCallManager{
    
    //MARK:- GROUP Call Methods
    ///*Start group call from agent
    
    func startGroupCall(with call: Call, with groupCallData : CallClientGroupCallData){
        transactionID = groupCallData.transactionId!
//        CallClient.shared.videoCallEnabled = call.type.rawValue
//        CallClient.shared.fullName = groupCallData.userType!
        if isCallJoinedFromLink {
            return
        }
        timeElapsedSinceGroupCallStart = 0
        activeCall = call
        addSignalReceiver()
        //        transactionID = groupCallData.userType
        let links = createGroupCallLink(with: groupCallData, for: call)
        link = links.0
        jitsiUrl = links.1
        showJitsiViewForGroupCall(groupCallData)
    }
    
    
    func startRecievedGroupCall(newCall: Call, signal: JitsiCallSignal){
        if activeCall != nil{
            updateActiveCallInfoIfRequired(newCall)
            return // activeCall?.uID != newCall.uID user busy on another call
        }
        if muidDic?.keys.first == newCall.uID, muidDic?[newCall.uID] == true{
            return
        }
        transactionID = signal.transationID
        activeCall = newCall
        link = activeCall?.inviteLink ?? ""
        jitsiUrl = activeCall?.jitsiUrl ?? ""
        // reportIncomingCallOnCallKit()
        addSignalReceiver()
        openPopupForGroupCall()
    }
    
    func updateActiveCallInfoIfRequired(_ newCall : Call){
        if activeCall.uID == newCall.uID{
            if self.activeCall.currentUser.name == "User"{
                activeCall = newCall
            }
        }
    }
    
    
    func openPopupForGroupCall(){
        if let keyWindow = UIApplication.shared.windows.first {
            if muidDic?.keys.first == activeCall?.uID, muidDic?[activeCall?.uID ?? ""] == true{
                return
            }
            if RecievedGroupCallView.shared == nil {
                RecievedGroupCallView.shared = RecievedGroupCallView.loadView()
                RecievedGroupCallView.shared.isHidden = true
                guard  !keyWindow.subviews.contains(RecievedGroupCallView.shared) else {
                    RecievedGroupCallView.shared = nil
                    return
                }
                
                RecievedGroupCallView.shared.userInfo = userDataforDailCall()
                RecievedGroupCallView.shared.setUp()
                RecievedGroupCallView.shared.delegate = self
                print("ADD VIEW ON WINDOW*************** 7")
                keyWindow.addSubview(RecievedGroupCallView.shared)
                //RecievedGroupCallView.shared.playReceivedCallSound()
                
                //Add timer
                if repeatShowingPopupTimer == nil {
                    let timer = Timer(timeInterval: 2.0,
                                      target: self,
                                      selector: #selector(updateRepeatShowingPopupTimer),
                                      userInfo: nil,
                                      repeats: true)
                    RunLoop.current.add(timer, forMode: .common)
                    timer.tolerance = 0.1
                    self.repeatShowingPopupTimer = timer
                }
                isOfferRecieved = true
            }
        }
    }
    
    //MARK:- Methods to start group call
    /// start publishing *START_GROUP_CALL* from/ agentsdk on user channel and active channel once the agent joins the link
    private func sendStartGroupCall(completion: VersionMismatchCallBack? = nil){
        if activeCall == nil{
            return
        }
        
        let signal = JitsiCallSignal(signalType: .START_GROUP_CALL, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: false,transationID: transactionID, jitsiUrl: jitsiUrl ?? "")
        let dict = signal.getJsonToSendToFaye()
        sendData(dict: dict, completion:  { (mismatch) in
            if completion != nil{
                completion!(mismatch)
            }
        })
        if repeatGroupCallTimer == nil {
            let timer = Timer(timeInterval: 2.0,
                              target: self,
                              selector: #selector(updateTimerAndSendStartGroupCall),
                              userInfo: nil,
                              repeats: true)
            RunLoop.current.add(timer, forMode: .common)
            timer.tolerance = 0.1
            self.repeatGroupCallTimer = timer
        }
    }
    
    @objc private func updateTimerAndSendStartGroupCall(){
        self.timeElapsedSinceGroupCallStart += 2
        self.repeatStartGroupCall()
    }
    
    @objc private func updateRepeatShowingPopupTimer(){
        self.timeElapsedSincePopupShown += 2
        if !(maxRepeatTime > timeElapsedSincePopupShown){
            endrepeatShowingPopup()
            self.reportEndCallToCallKit(self.activeCall?.uID ?? "", .answeredElsewhere)
            muidDic = [String : Bool]()
            muidDic?[activeCall.uID] = true
            activeCall?.signalingClient.sendSessionStatus(status: "MISSED_GROUP_CALL", transactionId : transactionID ?? "")
            if JitsiConfrenceCallView.shared == nil{
                resetAllResourceForNewCall()
            }
        }
    }
    
    private func endrepeatShowingPopup(){
        repeatShowingPopupTimer?.invalidate()
        repeatShowingPopupTimer = nil
        timeElapsedSincePopupShown = 0
        removeRecievedGroupCallPopup()
    }
    
    
    private func endRepeatStartGroupCall(){
        repeatGroupCallTimer?.invalidate()
        repeatGroupCallTimer = nil
        timeElapsedSinceGroupCallStart = 0
    }
    
    private func repeatStartGroupCall(){
        if maxRepeatTime > timeElapsedSinceGroupCallStart, activeCall != nil { // send repeat call
            let signal = JitsiCallSignal(signalType: .START_GROUP_CALL, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true, jitsiUrl: jitsiUrl ?? "")
            let dict = signal.getJsonToSendToFaye()
            sendData(dict: dict)
        } else {
            self.endRepeatStartGroupCall()
        }
    }
    
    private func removeRecievedGroupCallPopup(){
        if RecievedGroupCallView.shared != nil {
            RecievedGroupCallView.shared.remove()
        }
    }
    
    func leaveConferenceOnForceKill(){
        
        if activeCall == nil{
            return
        }
        
        if isCallJoined{
            userDidTerminatedConference()
        }else{
            if (activeCall?.isGroupCall ?? false) == false{
                sendCallRejected()
            }else{
                if JitsiConfrenceCallView.shared != nil {
                    JitsiConfrenceCallView.shared.removeFromSuperview()
                    JitsiConfrenceCallView.shared.delegate = nil
                    JitsiConfrenceCallView.shared = nil
                }
                resetAllResourceForNewCall()
            }
        }
    }
    
    private func removeJitsiPopup(){
        JitsiConfrenceCallView.shared.leaveConfrence { [weak self](mark) in
            if mark {
                if JitsiConfrenceCallView.shared  == nil { return }
                JitsiConfrenceCallView.shared.removeNotification()
                JitsiConfrenceCallView.shared.removeFromSuperview()
                JitsiConfrenceCallView.shared.delegate = nil
                JitsiConfrenceCallView.shared = nil
                self?.resetAllResourceForNewCall()
            }
        }
        self.activeCall.signalingClient.sendSessionStatus(status: "END_GROUP_CALL",transactionId: transactionID ?? "")
    }
    
    private func rejectGroupCall(){
        if activeCall == nil {
            return
        }
        let signal = JitsiCallSignal(signalType: .REJECT_GROUP_CALL, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true,transationID: transactionID, jitsiUrl: jitsiUrl ?? "")
        muidDic = [String : Bool]()
        muidDic?[activeCall.uID] = true
        let dict = signal.getJsonToSendToFaye()
        sendData(dict: dict, completion: {(mark) in
            self.groupCallRejectedFromUser()
        })
        removeRecievedGroupCallPopup()
        activeCall?.signalingClient.sendSessionStatus(status: "REJECT_GROUP_CALL",transactionId: transactionID ?? "")
    }
    
    private func groupCallRejectedFromUser(){
        resetAllResourceForNewCall()
        removeRecievedGroupCallPopup()
    }
    
    private func acceptGroupCall(_ isCustomerJoinedFromApi : Bool = false){
        if activeCall == nil {
            return
        }
        let signal = JitsiCallSignal(signalType: .JOIN_GROUP_CALL, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true,transationID: transactionID, jitsiUrl: jitsiUrl ?? "")
        muidDic = [String : Bool]()
        muidDic?[activeCall.uID] = true
        let dict = signal.getJsonToSendToFaye()
        sendData(dict: dict)
        if !isCustomerJoinedFromApi{
            self.showJitsiView()
        }
        activeCall?.signalingClient.sendSessionStatus(status: "JOIN_GROUP_CALL", transactionId: transactionID ?? "")
    }
    
}


//Received call
extension JitsiCallManager {
    
    func showReceivedCallView() {
        if let keyWindow = UIApplication.shared.windows.first{
            
            if CallStartAndReceivedView.shared == nil {
                CallStartAndReceivedView.shared = CallStartAndReceivedView.loadView()
                //hide the view by default, so that i donot need to change the checks for user busy
                CallStartAndReceivedView.shared.isHidden = true
                guard  !keyWindow.subviews.contains(CallStartAndReceivedView.shared!) else {
                    CallStartAndReceivedView.shared = nil
                    return
                }
                
                CallStartAndReceivedView.shared.userInfo = self.userDataforDailCall()
                //                guard CallStartAndReceivedView.shared.userInfo.keys.count > 0 else {
                //                    CallStartAndReceivedView.shared = nil
                //                    return
                //                }
                CallStartAndReceivedView.shared.isCallRecieved = true
                CallStartAndReceivedView.shared.receivedCallSetup()
                CallStartAndReceivedView.shared.delegate = self
                
                //                if CallStartAndReceivedView.shared != nil{
                let subView = CallStartAndReceivedView.shared
                keyWindow.addSubview(subView!)
                keyWindow.makeKeyAndVisible()
                //                }else{
                //                    CallStartAndReceivedView.loadView()?.remove()
                //                }
            }
        }
    }
    
    func showDailCallView(completion: VersionMismatchCallBack? = nil) {
        if let keyWindow = UIApplication.shared.windows.first {
            if CallStartAndReceivedView.shared == nil {
                CallStartAndReceivedView.shared = CallStartAndReceivedView.loadView()
                CallStartAndReceivedView.shared.userInfo = userDataforDailCall()
                CallStartAndReceivedView.shared.dailCallSetup()
                CallStartAndReceivedView.shared.delegate = self
                keyWindow.addSubview(CallStartAndReceivedView.shared!)
                keyWindow.makeKeyAndVisible()
                CallStartAndReceivedView.shared.playDailCallSound()
                startTimerForConference(createCall: true)
                
                //                if JitsiCallSignal.JitsiSignalType.READY_TO_CONNECT_CONFERENCE == .READY_TO_CONNECT_CONFERENCE{
                //                    sendStartCallFirstTime(){ (mismatch) in
                //                        if completion != nil{
                //                            completion!(mismatch)
                //                        }
                //                    }
                //                }else{
                //                    sendStartCallFirstTimeForiOS(){ (mismatch) in
                //                        if completion != nil{
                //                            completion!(mismatch)
                //                        }
                //                    }
                //                }
                
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
    
    func showConnectingView(){
        if let keyWindow = UIApplication.shared.windows.first{
            if EstablishingConnectionView.shared == nil{
                EstablishingConnectionView.shared = EstablishingConnectionView.loadView(with: keyWindow.frame)
                keyWindow.addSubview(EstablishingConnectionView.shared)
            }else if keyWindow.subviews.contains(EstablishingConnectionView.shared) == false{
                keyWindow.addSubview(EstablishingConnectionView.shared)
            }
        }
    }
    
    
    func checkIfOfferIsSent(completion: @escaping (Bool) -> Void){
        if self.isOfferRecieved == true{
            removeConnectingView()
            completion(true)
            if self.activeCall?.isGroupCall ?? false{
                self.groupCallAnswered()
            }else{
                self.userDidAnswered()
            }
        }else{
            timeElapsedSinceWaitingForOffer += 1
            showConnectingView()
            
            if timeElapsedSinceWaitingForOffer > 20 && (self.isOfferRecieved ?? false) == false{
                completion(false)
                self.removeDialAndReceivedView()
                self.resetAllResourceForNewCall()
                self.removeConnectingView()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.checkIfOfferIsSent(completion: completion)
            }
        }
    }
    
    func removeConnectingView(){
        timeElapsedSinceWaitingForOffer = 0
        if EstablishingConnectionView.shared != nil{
            EstablishingConnectionView.shared.removeFromSuperview()
        }
    }
}



//MARK: - Socket Signal
extension JitsiCallManager {
    
    func addSignalReceiver() {
        if activeCall != nil {
            activeCall.signalingClient.signalReceivedFromPeer = nil // free the pervious
            activeCall?.signalingClient.signalReceivedFromPeer  = { [weak self] (jsonDict) in
                guard let signalTypeRaw = jsonDict["video_call_type"] as? String,let  signalType = JitsiCallSignal.JitsiSignalType(rawValue:signalTypeRaw) else {
                    return
                }
                
                let signal = JitsiCallSignal.getFrom(json: jsonDict)
                var  userId = jsonDict["user_id"] as? Int
                if userId == nil {
                    let strId = jsonDict["user_id"] as? String
                    if let someStrId = strId, let intId = Int(someStrId) {
                        userId = intId
                    }
                }
                
                guard signal?.senderDeviceID != CallClient.shared.currentDeviceID else {
                    return
                }
                
                switch signalType {
                case .START_CONFERENCE_IOS:
                    //                      self?.sendReadyToConnect()
                    //                    self?.showReceivedCallView()
                    break// nerver come on socket alway come from push
                case .START_CONFERENCE:
                    //                    self?.sendReadyToConnect()
                    //                    self?.showReceivedCallView()
                    break// nerver come on socket alway come from push
                case .READY_TO_CONNECT_CONFERENCE :
                    //self?.endRepeatStartCall()
                    if CallStartAndReceivedView.shared == nil || JitsiConfrenceCallView.shared != nil{
                        return
                    }
                    if self?.activeCall.currentUser.peerId == signal?.sender.peerId{
                        return
                    }
                    
                    if self?.link != signal?.conferenceLink{
                        return
                    }
                    
                    if (CallStartAndReceivedView.shared != nil){
                        CallStartAndReceivedView.shared.callStateText = HippoCallClientStrings.ringing
                    }
                    self?.sendOffer()
                case .ANSWER_CONFERENCE:
                    guard signal?.sender.peerId != self?.activeCall?.currentUser.peerId  else {
                        ///if answer_conference recieved from same user (peerid) from another device
                        self?.endRepeatStartCalliOS()
                        self?.endRepeatStartCall()
                        self?.removeDialAndReceivedView()
                        self?.resetAllResourceForNewCall()
                        self?.muidOne2oneDic = [String : Bool]()
                        self?.muidOne2oneDic?[signal?.callUID ?? ""] = true
                        // JMCallKitProxy.muidOne2oneDic = self?.muidOne2oneDic ?? [String : Bool]()
                        return
                    }
                    
                    if (CallStartAndReceivedView.shared != nil) {
                        self?.endRepeatStartCalliOS()
                        self?.endRepeatStartCall()
                        self?.jitsiUrl = signal?.jitsiUrl
                        self?.receivedAnswerFromOtherUser()
                        self?.removeStartConTimer(for: true, createCall: false)
                    }
                    
                case .OFFER_CONFERENCE:
                    guard signal?.sender.peerId != self?.activeCall?.currentUser.peerId  else {
                        return
                    }
                    if JitsiConfrenceCallView.shared != nil{
                        return
                    }
                    
                    if self?.userBusy_Muid == signal?.callUID{
                        self?.reportEndCallToCallKit(signal?.callUID ?? "", .failed)
                        return
                    }
                    
                    if CallStartAndReceivedView.shared == nil {
                        self?.showReceivedCallView()
                        self?.isOfferRecieved = true
                    }
                    
                case .REJECT_CONFERENCE:
                    self?.reportEndCallToCallKit(self?.activeCall?.uID ?? "", .declinedElsewhere)
                    self?.muidOne2oneDic = [String : Bool]()
                    self?.muidOne2oneDic?[signal?.callUID ?? ""] = true
                    //JMCallKitProxy.muidOne2oneDic = self?.muidOne2oneDic ?? [String : Bool]()
                    self?.receivedRejectCallFromOtherUser()
                case .HUNGUP_CONFERENCE:
                    self?.muidOne2oneDic = [String : Bool]()
                    self?.muidOne2oneDic?[signal?.callUID ?? ""] = true
                    //JMCallKitProxy.muidOne2oneDic = self?.muidOne2oneDic ?? [String : Bool]()
                    self?.reportEndCallToCallKit(signal?.callUID ?? "", .answeredElsewhere)
                    if self?.activeCall?.uID == signal?.callUID{
                        self?.otherUserCallHungup()
                    }
                case .USER_BUSY_CONFERENCE:
                    self?.userBusy_Muid = signal?.callUID
                    self?.otherUserBusyOnOtherCall()
                case .READY_TO_CONNECT_CONFERENCE_IOS:
                    //self?.endRepeatStartCalliOS()
                    if CallStartAndReceivedView.shared == nil || JitsiConfrenceCallView.shared != nil{
                        return
                    }
                    if self?.activeCall.currentUser.peerId == signal?.sender.peerId{
                        return
                    }
                    
                    if self?.link != signal?.conferenceLink{
                        return
                    }
                    if (CallStartAndReceivedView.shared != nil){
                        CallStartAndReceivedView.shared.callStateText = HippoCallClientStrings.ringing
                    }
                    self?.sendOffer()
                    break
                case .START_GROUP_CALL:
                    break
                case .REJECT_GROUP_CALL:
                    //if user_id is same and device_id is different remove popup
                    ///This condition is to remove popup from other devices if call is  */REJECTED/*  from same user id
                    if  signal?.sender.peerId == self?.activeCall?.currentUser.peerId && signal?.senderDeviceID != CallClient.shared.currentDeviceID{
                        self?.reportEndCallToCallKit(self?.activeCall?.uID ?? "", .answeredElsewhere)
                        self?.removeRecievedGroupCallPopup()
                        self?.resetAllResourceForNewCall()
                        self?.muidDic = [String : Bool]()
                        self?.muidDic?[signal?.callUID ?? ""] = true
                        self?.removeConnectingView()
                    }
                    break
                case .JOIN_GROUP_CALL:
                    //if user_id is same and device_id is different remove popup
                    ///This condition is to remove popup from other devices if call is */ACCEPTED/*  from same user id
                    if  signal?.sender.peerId == self?.activeCall?.currentUser.peerId && signal?.senderDeviceID != CallClient.shared.currentDeviceID{
                        self?.reportEndCallToCallKit(self?.activeCall?.uID ?? "", .answeredElsewhere)
                        self?.removeRecievedGroupCallPopup()
                        self?.resetAllResourceForNewCall()
                        self?.muidDic = [String : Bool]()
                        self?.muidDic?[signal?.callUID ?? ""] = true
                    }
                    break
                case .END_GROUP_CALL:
                    ///end Call session on listening */END_GROUP_CALL/* from agent
                    if signal?.transationID == self?.transactionID{
                        self?.reportEndCallToCallKit(self?.activeCall?.uID ?? "", .answeredElsewhere)
                        self?.removeRecievedGroupCallPopup()
                        self?.removeJitsiPopup()
                        self?.removeConnectingView()
                    }
                    break
                    
                case .CALL_HUNG_UP:
                    if  signal?.sender.peerId == self?.activeCall?.currentUser.peerId && signal?.callUID == self?.activeCall.uID && signal?.senderDeviceID != CallClient.shared.currentDeviceID{
                        self?.reportEndCallToCallKit(self?.activeCall?.uID ?? "", .answeredElsewhere)
                        self?.removeDialAndReceivedView()
                        self?.resetAllResourceForNewCall()
                        self?.removeConnectingView()
                    }
                    break
                }
            }
        }
    }
    
    func startTimerForConference(createCall: Bool){
        if (activeCall != nil){
            if startConTimer == nil {
                let timer = Timer(timeInterval: 2.0,
                                  target: self,
                                  selector: #selector(updateStartConTimer),
                                  userInfo: nil,
                                  repeats: true)
                RunLoop.current.add(timer, forMode: .common)
                timer.tolerance = 0.1
                self.startConTimer = timer
            }
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
            guard self.activeCall != nil else {
                return
            }
            self.activeCall.signalingClient.sendJitsiObject(json: dict) { [weak self] (mark, error) in
                if !mark{
                    // Logger.shared.printVar(for: error?.localizedDescription)
                    if (error?.code == 415){
                        self?.removeDialAndReceivedView()
                        self?.removeStartConTimer(for: false, createCall: true)
                        self?.resetAllResourceForNewCall()
                        completion?(true)
                    }else if (error?.code == 421){
                        self?.endRepeatStartGroupCall()
                        completion?(true)
                    }
                }else{
                    completion?(false)
                }
            }
        })
    }
    
    func sendStartCallFirstTime(completion: VersionMismatchCallBack? = nil) {
        if activeCall == nil{
            return
        }
        let signal = JitsiCallSignal(signalType: .START_CONFERENCE, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: false, jitsiUrl: jitsiUrl ?? "")
        let dict = signal.getJsonToSendToFaye()
        sendData(dict: dict, completion:  { (mismatch) in
            if completion != nil{
                completion!(mismatch)
            }
        })
        
        if repeatTimer == nil {
            let timer = Timer(timeInterval: 5.0,
                              target: self,
                              selector: #selector(updateTimerForSendStartCall),
                              userInfo: nil,
                              repeats: true)
            RunLoop.current.add(timer, forMode: .common)
            timer.tolerance = 0.1
            self.repeatTimer = timer
        }
    }
    
    @objc func updateTimerForSendStartCall(){
        self.timeElapsedSinceCallStart += 5
        self.sendRepeatStartCall()
    }
    
    
    func sendStartCallFirstTimeForiOS(completion: VersionMismatchCallBack? = nil) {
        if activeCall == nil{
            return
        }
        let signal = JitsiCallSignal(signalType: .START_CONFERENCE_IOS, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: false, jitsiUrl: jitsiUrl ?? "")
        let dict = signal.getJsonToSendToFaye()
        sendData(dict: dict, completion:  { (mismatch) in
            if completion != nil{
                completion!(mismatch)
            }
        })
        
        if repeatTimeriOS == nil {
            let timer = Timer(timeInterval: 5.0,
                              target: self,
                              selector: #selector(updateTimerForSendStartIosCall),
                              userInfo: nil,
                              repeats: true)
            RunLoop.current.add(timer, forMode: .common)
            timer.tolerance = 0.1
            self.repeatTimeriOS = timer
        }
    }
    
    @objc func updateTimerForSendStartIosCall(){
        self.timeElapsedSinceCallStartiOS += 5
        self.sendRepeatStartCalliOS()
    }
    
    func sendRepeatStartCalliOS() {
        if maxRepeatTime > timeElapsedSinceCallStartiOS, activeCall != nil { // send repeat call
            let signal = JitsiCallSignal(signalType: .START_CONFERENCE_IOS, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true, jitsiUrl: jitsiUrl ?? "")
            let dict = signal.getJsonToSendToFaye()
            sendData(dict: dict)
        } else {
            self.endRepeatStartCalliOS()
        }
    }
    
    func sendRepeatStartCall() {
        if maxRepeatTime > timeElapsedSinceCallStart, activeCall != nil { // send repeat call
            let signal = JitsiCallSignal(signalType: .START_CONFERENCE, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true, jitsiUrl: jitsiUrl ?? "")
            let dict = signal.getJsonToSendToFaye()
            sendData(dict: dict)
        }else { // remove
            self.endRepeatStartCall()
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
        let signal = JitsiCallSignal(signalType: .OFFER_CONFERENCE, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true, jitsiUrl: jitsiUrl ?? "")
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
        let signal = JitsiCallSignal(signalType: .READY_TO_CONNECT_CONFERENCE_IOS, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true, jitsiUrl: jitsiUrl ?? "")
        let dict = signal.getJsonToSendToFaye()
        sendData(dict: dict)
        startTimerForConference(createCall: false)
    }
    
    
    func sendAnswered() {
        if activeCall == nil {
            return
        }
        let signal = JitsiCallSignal(signalType: .ANSWER_CONFERENCE, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true, jitsiUrl: jitsiUrl ?? "")
        let dict = signal.getJsonToSendToFaye()
        sendData(dict: dict)
        self.muidOne2oneDic = [String : Bool]()
        self.muidOne2oneDic?[signal.callUID] = true
        //JMCallKitProxy.muidOne2oneDic = self.muidOne2oneDic ?? [String : Bool]()
        self.removeStartConTimer(for: true, createCall: false)
    }
    
    func sendCallRejected() {
        if activeCall == nil {
            return
        }
        
        let signal = JitsiCallSignal(signalType: .REJECT_CONFERENCE, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true, jitsiUrl: jitsiUrl ?? "")
        let dict = signal.getJsonToSendToFaye()
        sendData(dict: dict, completion: {(mark) in
            self.muidOne2oneDic = [String : Bool]()
            self.muidOne2oneDic?[self.activeCall?.uID ?? ""] = true
            //JMCallKitProxy.muidOne2oneDic = self.muidOne2oneDic ?? [String : Bool]()
            self.callRejectByCurrentUser()
        })
        
        sendCallHungup()
        removeDialAndReceivedView()
    }
    
    
    func sendBusy(with otherCall: Call, and signal: JitsiCallSignal) {
        let signal = JitsiCallSignal(signalType: .USER_BUSY_CONFERENCE, callUID: otherCall.uID, sender: otherCall.currentUser, senderDeviceID: otherCall.uID , callType: otherCall.type , link: callingType == 3 ? jitsiUrl ?? "" : signal.conferenceLink ?? "", isFSilent: true, jitsiUrl: jitsiUrl ?? "")
        let dict = signal.getJsonToSendToFaye()
        otherCall.signalingClient.connectClient(completion: { (success) in
            otherCall.signalingClient.sendJitsiObject(json: dict) { (mark, error) in}
        })
    }
    
    func otherUserCallHungup() {
        if JitsiConfrenceCallView.shared != nil{
            JitsiConfrenceCallView.shared.leaveConfrence { [weak self](mark) in
                DispatchQueue.main.async {
                    if mark {
                        if JitsiConfrenceCallView.shared  == nil { return }
                        JitsiConfrenceCallView.shared.removeFromSuperview()
                        JitsiConfrenceCallView.shared.delegate = nil
                        JitsiConfrenceCallView.shared = nil
                        self?.resetAllResourceForNewCall()
                    }
                }
            }
        }else {
            removeConnectingView()
            removeDialAndReceivedView()
            resetAllResourceForNewCall()
        }
        self.removeStartConTimer(for: false, createCall: false)
    }
    
    func sendCallHungup() {
        if activeCall != nil {
            let signal = JitsiCallSignal(signalType: .HUNGUP_CONFERENCE, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true , jitsiUrl: jitsiUrl ?? "")
            let dict = signal.getJsonToSendToFaye()
            sendData(dict: dict, completion: { (mismatch) in
//                self.resetAllResourceForNewCall()
            })
            idForHungUpSent = activeCall?.uID
            self.resetAllResourceForNewCall()
        }
        if JitsiConfrenceCallView.shared != nil {
            JitsiConfrenceCallView.shared.removeFromSuperview()
            JitsiConfrenceCallView.shared.delegate = nil
            JitsiConfrenceCallView.shared = nil
        }
    }
    
    func otherUserBusyOnOtherCall() {
        endRepeatStartCalliOS()
        endRepeatStartCall()
        resetAndShowBusy(with: HippoCallClientStrings.busyOnOtherCall)
    }
}

extension JitsiCallManager : CallStartAndReceivedViewDelegate {
    
    
    func userDidCanceledDialCall() {
        if activeCall != nil {
            let signal = JitsiCallSignal(signalType: .HUNGUP_CONFERENCE, callUID: activeCall!.uID, sender: activeCall!.currentUser, senderDeviceID: activeCall?.uID ?? "", callType: activeCall!.type , link: link, isFSilent: true , jitsiUrl: jitsiUrl ?? "")
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
        resetAndShowBusy(with: HippoCallClientStrings.callDeclined)
    }
    
    func removeDialAndReceivedView() {
        if CallStartAndReceivedView.shared != nil {
            CallStartAndReceivedView.shared.remove()
        }
        
    }
    
    func showJitsiViewToJoinLink(customerName: String, customerImage: String, url: String, isInviteEnabled: Bool) {
        if let keyWindow = UIApplication.shared.windows.first{
            if JitsiConfrenceCallView.shared == nil && activeCall == nil {
                let tempLink = getLinkAfertRemoveAudio(link: (jitsiUrl ?? "") == "" ? link : jitsiUrl ?? "")
                let data = getURLOrRoomId(for: tempLink)
                let inviteLink = data.url
                let roomId = data.roomId
                let imageURL = URL(string: customerImage)
                let model = JitsiMeetDataModel(userName: customerName, userEmail: "", userImage: imageURL, audioOnly: self.link.contains("startWithVideoMuted=true") ? true : false, serverURl: inviteLink, roomID: roomId, isMuted: false)
                model.isInviteEnabled = isInviteEnabled
                JitsiConfrenceCallView.shared = JitsiConfrenceCallView.loadView(with: keyWindow.frame)
                JitsiConfrenceCallView.shared.setupJitsi(for: model)
                JitsiConfrenceCallView.shared.delegate = self
                keyWindow.addSubview(JitsiConfrenceCallView.shared)
            }
        }
    }
    
    
    func showJitsiViewForGroupCall(_ groupCallData : CallClientGroupCallData){
        if let keyWindow = UIApplication.shared.windows.first{
            if JitsiConfrenceCallView.shared == nil && activeCall != nil {
                let imageURL = URL(string: activeCall.currentUser.image)
                let tempLink = getLinkAfertRemoveAudio(link: (jitsiUrl ?? "") == "" ? link : jitsiUrl ?? "")
                let data = getURLOrRoomId(for: tempLink)
                let inviteLink = data.url
                guard let roomId = groupCallData.roomUniqueId else{
                    return
                }
                let model = JitsiMeetDataModel(userName: activeCall.currentUser.name, userEmail: "", userImage: imageURL, audioOnly: activeCall.type == .audio ? true : false, serverURl: inviteLink, roomID: roomId, isMuted: groupCallData.isMuted ?? false)
                model.isInviteEnabled = isInviteEnabled
                JitsiConfrenceCallView.shared = JitsiConfrenceCallView.loadView(with: keyWindow.frame)
                JitsiConfrenceCallView.shared.setupJitsi(for: model)
                JitsiConfrenceCallView.shared.delegate = self
                keyWindow.addSubview(JitsiConfrenceCallView.shared)
                self.sendStartGroupCall()
                if groupCallData.userType == "customer"{
                    self.acceptGroupCall(true)
                }
                
                self.activeCall?.signalingClient.sendSessionStatus(status: "START_GROUP_CALL", transactionId : transactionID ?? "")
            }
        }
    }
    
    func showJitsiView() {
        DispatchQueue.main.async {
            if let keyWindow = UIApplication.shared.windows.first{
                print("come in join call -------->>>>>>>>>>",JitsiConfrenceCallView.shared,self.activeCall)
                if JitsiConfrenceCallView.shared == nil && self.activeCall != nil {
                    //signal?.senderDeviceID != CallClient.shared.currentDeviceID
                    let model = self.userDataForOutgoingCall()
                    if self.link.contains("startWithVideoMuted"){
                        model.audioOnly = true
                    }
                    if self.link.contains("startWithAudioMuted"){
                        model.isMuted = true
                    }
                    model.isInviteEnabled = self.isInviteEnabled
                    JitsiConfrenceCallView.shared = JitsiConfrenceCallView.loadView(with: keyWindow.frame)
                    JitsiConfrenceCallView.shared.setupJitsi(for: model)
                    JitsiConfrenceCallView.shared.delegate = self
                    keyWindow.addSubview(JitsiConfrenceCallView.shared)
                }
            }
            self.endrepeatShowingPopup()
            self.removeDialAndReceivedView()
        }
    }
    
    func userDataForOutgoingCall() -> JitsiMeetDataModel {
        let userName = activeCall.currentUser.name
        let email = ""
        let imageURL = URL(string: activeCall.currentUser.image)
        let audioOnly = activeCall.type == .audio ? true : false
        let tempLink = getLinkAfertRemoveAudio(link: (jitsiUrl ?? "") == "" ? link : jitsiUrl ?? "")
        let data = getURLOrRoomId(for: tempLink)
        //Logger.shared.printVar(for: data.url.absoluteString)
        print("tempLink is", tempLink, data.url)
        let userModel = JitsiMeetDataModel(userName: userName, userEmail: email, userImage: imageURL, audioOnly: audioOnly, serverURl: data.url, roomID: data.roomId, isMuted: false)
        return userModel
    }
    
    func resetAllResourceForNewCall() {
        print("resetAllResourceForNewCall called ---------------")
        
        if let actCall = activeCall{
            self.reportEndCallToCallKit(actCall.uID, .failed)
        }
        
        isCallJoinedFromLink = false
        isInviteEnabled = false
        activeCall = nil
        link = nil
        repeatTimer?.invalidate()
        repeatTimeriOS?.invalidate()
        startConTimer?.invalidate()
        repeatTimer = nil
        repeatTimeriOS = nil
        startConTimer = nil
        repeatGroupCallTimer?.invalidate()
        repeatShowingPopupTimer?.invalidate()
        repeatShowingPopupTimer = nil
        repeatGroupCallTimer = nil
        timeElapsedSincePopupShown = 0
        timeElapsedSinceGroupCallStart = 0
        timeSinceStartCon = 0
        timeElapsedSinceCallStart = 0
        timeElapsedSinceCallStartiOS = 0
        receivedCallData = nil
        isCallJoined = false
        timeElapsedSinceWaitingForOffer = 0
        isOfferRecieved = nil
        jitsiUrl = nil
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
    
    func createLink(for call: Call)-> (String, String) {
        let url = JitsiConstants.inviteLink
        //let randomStr = call.transactionId == nil ? randomString(length: 11) + "iOS" : (call.transactionId ?? "")
        let randomStr = call.transactionId == nil || call.transactionId == "" ? randomString(length: 11) + "iOS" : (call.transactionId ?? "")
        var link = url + randomStr
        var jitsiLink = call.jitsiUrl != "" ? call.jitsiUrl + "/" + randomStr : ""
        if call.type == .audio {
            link += "#config.startWithVideoMuted=true"
            jitsiLink += call.jitsiUrl != "" ? "#config.startWithVideoMuted=true" : ""
        }
        return (link,jitsiLink)
    }
    
    func createGroupCallLink(with groupCallData: CallClientGroupCallData,for call: Call)-> (String, String) {
        let url = JitsiConstants.inviteLink
        var link = url + (groupCallData.roomUniqueId ?? "")
        var jitsiLink = call.jitsiUrl != "" ? (call.jitsiUrl + "/" + (groupCallData.roomUniqueId ?? "")) : ""
        var config = ""
        if groupCallData.isMuted ?? false && call.type == .audio{
            config = "#config.startWithAudioMuted=true" + "&config.startWithVideoMuted=true"
        }else if groupCallData.isMuted ?? false{
            config = "#config.startWithAudioMuted=true"
        }else if call.type == .audio{
            config = "#config.startWithVideoMuted=true"
        }
        
        link += config
        jitsiLink += call.jitsiUrl != "" ? config : ""
        
        return (link,jitsiLink)
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
        _ = link.replacingOccurrences(of: roomId, with: "")
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
        isCallStarted?(true)
        if UIApplication.shared.isProtectedDataAvailable{
            reportEndCallToCallKit(activeCall?.uID ?? "", .remoteEnded)
        }
        print("----->>>>>>>> conference joined")
    }
    
    func userWillLeaveConference() {
        
    }
    
    func userDidTerminatedConference() {
        
        isCallJoinedFromLink = false
        self.reportEndCallToCallKit(self.activeCall?.uID ?? "", .remoteEnded)
        
        if (activeCall?.isGroupCall ?? false) == false{
            sendCallHungup()
        }else{
            if JitsiConfrenceCallView.shared != nil {
                JitsiConfrenceCallView.shared.leaveConfrence {(mark) in
                    if mark {
                        JitsiConfrenceCallView.shared.removeFromSuperview()
                        JitsiConfrenceCallView.shared.delegate = nil
                        JitsiConfrenceCallView.shared = nil
                    }
                }
                resetAllResourceForNewCall()
            }
            isCallJoined = false
            isCallStarted?(false)
        }
    }
    
    func userDidEnterPictureInPicture() {
        
    }
    
    func keyWindowChanged(){
        if activeCall != nil && JitsiConfrenceCallView.shared != nil{
            JitsiConfrenceCallView.shared.removeFromSuperview()
            DispatchQueue.main.async {
                if let keyWindow = UIApplication.shared.windows.first{
                    keyWindow.addSubview(JitsiConfrenceCallView.shared)
                }
            }
        }
    }
    
}
extension JitsiCallManager : RecievedGroupCallDelegate{
    func groupCallAnswered(){
        acceptGroupCall()
    }
    func groupCallCancelled(){
        rejectGroupCall()
    }
}


extension JitsiCallManager{
    func hideJitsiView(){
        if JitsiConfrenceCallView.shared != nil{
            JitsiConfrenceCallView.shared.hideJitsiView()
        }
    }
    
    func unHideJitsiView(){
        if JitsiConfrenceCallView.shared != nil{
            JitsiConfrenceCallView.shared.showJitsiView()
        }
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
