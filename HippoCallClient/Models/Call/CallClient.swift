
//
//  VideoCallManager.swift
//  HippoCallClient
//
//  Created by Vishal on 03/09/18.
//  Copyright © 2018 Vishal. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications
import SafariServices
import AVFoundation


let utcDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
}()

enum EncodingType {
    case json
    case url
    
    func getContentType() -> String {
        switch  self {
        case .url:
            return "application/x-www-form-urlencoded"
        case .json:
            return "application/json"
        }
    }
}


class CallClient{
    static var shared = CallClient()
    
    // MARK: - Properties
    private(set) var activeCall: Call?
    fileprivate var callPresenter: CallPresenter!
    var currentDeviceID = UIDevice.current.identifierForVendor?.uuidString ?? ""
    fileprivate let maxTimeInNotConnectedState = 30
    
    fileprivate var credentials: CallClientCredential!
    fileprivate var credentialRetry = 0
    var videoSdkToken = ""
    //    var meetingID = ""
    //    var url = ""
    //    var appSecretKey = ""
    //    let sender: CallPeer =
    //    var enCodingType = [EncodingType]()
    var enCodeType = EncodingType.json
    //    var accesstoken = ""
    //    var callingType = UserDefaults.standard.value(forKey: "callingType") as? Int
    //    var callTypeAudio = ""
    //    var videoCallEnabled: String = "false"
    //    var jsonSignalDictionary : [AnyHashable: Any] = [:]
    //    var newUrl = ""
    //    @objc weak var object: AnyObject?
    //    var channelID = ""
    
    
    // MARK: - Methods
    func setCredentials(rawCredentials: [String: Any]) {
        self.credentials = CallClientCredential(rawCredentials: rawCredentials)
    }
    
    func voipNotificationRecievedForGroupCall(dictionary: [AnyHashable: Any], peer: CallPeer, signalingClient: SignalingClient, currentUser: CallPeer,isInviteEnabled: Bool){
        guard let jsonDict = dictionary as? [String: Any] else {
            return
        }
        
        guard let signal = JitsiCallSignal.getFrom(json: jsonDict) else {
            return
        }
        let call = Call(peer: peer, signalingClient: signalingClient, uID: signal.callUID, currentUser: currentUser, type: signal.callType, link: signal.conferenceLink ?? "", isGroupCall: true, jitsiUrl: signal.jitsiUrl, transactionId: nil)
        self.handleCallEvent(for: jsonDict, call: call, jitsiSignal: signal, isInviteEnabled: isInviteEnabled )
    }
    
    func voipNotificationReceived(dictionary: [AnyHashable: Any], peer: CallPeer, signalingClient: SignalingClient, currentUser: CallPeer,isInviteEnabled: Bool) {
        NSLog("Voip received in call client")
        guard let jsonDict = dictionary as? [String: Any] else {
            return
        }
        //        jsonSignalDictionary = dictionary
        guard credentials != nil else {
            NSLog("Credential Not found")
            return
        }
        
        func handleForGitSi() {
            guard let signal = JitsiCallSignal.getFrom(json: jsonDict) else {
                return
            }
            let call = Call(peer: peer, signalingClient: signalingClient, uID: signal.callUID, currentUser: currentUser, type: signal.callType, link: signal.conferenceLink ?? "",jitsiUrl: signal.jitsiUrl, transactionId: nil)
            self.handleCallEvent(for: jsonDict, call: call, jitsiSignal: signal, isInviteEnabled: isInviteEnabled )
        }
        
        func handleForWebRtc() {
            
            let timeout = TimeInterval(maxTimeInNotConnectedState)
            func isPushExpired(pushRecievedAt date: Date) -> Bool {
                let currentDate = Date()
                return date.addingTimeInterval(timeout).compare(currentDate) == .orderedAscending
            }
            guard let signal = CallSignal.getFrom(json: jsonDict) else {
                return
            }
            //            guard
            //                let dateString = jsonDict["date_time"] as? String,
            //                let date = utcDateFormatter.date(from: dateString),
            //                (!isPushExpired(pushRecievedAt: date) || signal.signalType != .startCall) else {
            //                    NSLog("Expired Voip Push received")
            //                    return
            //            }
            
            let call = Call(peer: peer, signalingClient: signalingClient, uID: signal.callUID, currentUser: currentUser, type: signal.callType, link: "", jitsiUrl: "", transactionId: nil)
            
            if !shouldHandle(signal: signal, call: call) {
                print("ERROR -> VOIP PUSH FROM CURRENT USER")
                return
            }
            if signal.signalType == .startCall || signal.signalType == .callRejected || signal.signalType == .callHungUp {
                takeActionOnSignalReceived(signal, forCall: call)
            }
        }
        
        if let notificationTypeInt = jsonDict["notification_type"] as? Int {
            
            switch notificationTypeInt {
            case 20: // gitsi
                handleForGitSi()
            default:
                handleForWebRtc()
            }
        }
        else if let _ = JitsiCallSignal.getFrom(json: jsonDict) {
            handleForGitSi()
        }
        else {
            handleForWebRtc()
        }
        
    }
    
    func getLastVisibleController(ofParent parent: UIViewController? = nil) -> UIViewController? {
        if let vc = parent {
            if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
                return getLastVisibleController(ofParent: selected)
            } else if let nav = vc as? UINavigationController, let top = nav.topViewController {
                return getLastVisibleController(ofParent: top)
            } else if let presented = vc.presentedViewController {
                return getLastVisibleController(ofParent: presented)
            } else {
                return vc
            }
        } else {
            if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                return getLastVisibleController(ofParent: rootVC)
            } else {
                return nil
            }
        }
    }
    
    func joinVideoSdkCall() {
        let needsCamera = JitsiCallManager.shared.callTypeForIncomingCall == .video
        withCameraPermission(cameraRequested: needsCamera) { [weak self] cameraGranted in
            guard let self = self else { return }
            let bundle = Bundle(identifier: "org.cocoapods.HippoCallClient")
            guard let vVc = UIStoryboard(name: "VideoSdk", bundle: bundle).instantiateViewController(withIdentifier: "MeetingViewController") as? MeetingViewController else { return }
            vVc.meetingData = MeetingData(token: self.videoSdkToken, name: HippoCallClientUrl.shared.userName, meetingId: JitsiCallManager.shared.nativeMeetID, micEnabled: true, cameraEnabled: cameraGranted)
            vVc.delegate = JitsiCallManager.shared
            JitsiCallManager.shared.videoSdkView = vVc
            let nav = UINavigationController(rootViewController: vVc)
            nav.modalPresentationStyle = .overFullScreen
            self.getLastVisibleController()?.present(nav, animated: true, completion: nil)
        }
    }
    
    func joinVideoSdkCallByMeetingID(serverToken: String, meetingID: String, name: String? = nil, startTime: String? = nil, endTime: String? = nil) {
        withAVPermissions { [weak self] granted in
            guard granted, let self = self else { return }
            let bundle = Bundle(identifier: "org.cocoapods.HippoCallClient")
            guard let vVc = UIStoryboard(name: "VideoSdk", bundle: bundle)
                .instantiateViewController(withIdentifier: "StartMeetingViewController")
                as? StartMeetingViewController else { return }
            vVc.serverToken = serverToken
            vVc.meetingID = meetingID
            vVc.presetName = name
            vVc.meetingStartTime = startTime
            vVc.meetingEndTime = endTime
            let nav = UINavigationController(rootViewController: vVc)
            nav.modalPresentationStyle = .overFullScreen
            self.getLastVisibleController()?.present(nav, animated: true, completion: nil)
        }
    }

    func joinMeeting(serverToken: String, meetingID: String, name: String, micEnabled: Bool, cameraEnabled: Bool, meetingDuration: TimeInterval) {
        withCameraPermission(cameraRequested: cameraEnabled) { [weak self] cameraGranted in
            guard let self = self else { return }
            let bundle = Bundle(identifier: "org.cocoapods.HippoCallClient")
            guard let vVc = UIStoryboard(name: "VideoSdk", bundle: bundle).instantiateViewController(withIdentifier: "MeetingViewController") as? MeetingViewController else { return }
            vVc.meetingDuration = meetingDuration
            vVc.meetingData = MeetingData(token: serverToken, name: name, meetingId: meetingID, micEnabled: micEnabled, cameraEnabled: cameraGranted)
            vVc.delegate = JitsiCallManager.shared
            JitsiCallManager.shared.videoSdkView = vVc
            let nav = UINavigationController(rootViewController: vVc)
            nav.modalPresentationStyle = .overFullScreen
            self.getLastVisibleController()?.present(nav, animated: true, completion: nil)
        }
    }
    
    func appSecretFromHippoCallClient(key: String, agentToken: String, userType: userType){
        HippoCallClientUrl.shared.appSecretKey = key
        HippoCallClientUrl.shared.agentToken = agentToken
        HippoCallClientUrl.shared.userType = userType
    }
    
    private func withCameraPermission(cameraRequested: Bool, completion: @escaping (Bool) -> Void) {
        guard cameraRequested else {
            completion(false)
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if !granted { self?.showCameraRequiredAlert() }
                    completion(granted)
                }
            }
        case .denied, .restricted:
            showCameraRequiredAlert()
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private func withAVPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { completion(false); return }
                self.checkMicPermission(completion: completion)
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self else { completion(false); return }
                    if granted {
                        self.checkMicPermission(completion: completion)
                    } else {
                        self.showAVPermissionPopup(isCamera: true)
                        completion(false)
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in
                self?.showAVPermissionPopup(isCamera: true)
                completion(false)
            }
        @unknown default:
            completion(false)
        }
    }

    private func checkMicPermission(completion: @escaping (Bool) -> Void) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            DispatchQueue.main.async {
                completion(true)
            }
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self else { completion(false); return }
                    if granted {
                        completion(true)
                    } else {
                        self.showAVPermissionPopup(isCamera: false)
                        completion(false)
                    }
                }
            }
        case .denied:
            DispatchQueue.main.async { [weak self] in
                self?.showAVPermissionPopup(isCamera: false)
                completion(false)
            }
        @unknown default:
            completion(false)
        }
    }

    private func showAVPermissionPopup(isCamera: Bool) {
        DispatchQueue.main.async {
            let popup = AVPermissionPopupView(
                icon: isCamera ? "camera.fill" : "mic.fill",
                title: isCamera ? "Camera Access Required" : "Microphone Access Required",
                message: isCamera
                    ? "Camera access is needed for video calls. Please enable it in Settings."
                    : "Microphone access is needed for video calls. Please enable it in Settings."
            )
            popup.present()
        }
    }

    private func showCameraRequiredAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Camera Access Required",
                message: "Camera access is required for video calls. Please enable it in Settings.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            })
            alert.addAction(UIAlertAction(title: "Continue Without Camera", style: .cancel))
            self.getLastVisibleController()?.present(alert, animated: true)
        }
    }

    fileprivate func showAlert(with message: String) {
        let alert = UIAlertController(title: "Alert", message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
        
        let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        
        if var topController = keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            
            DispatchQueue.main.async {
                topController.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    func getVideoSdkTokenNative(comingFrom: String = "", transaction_id: String = "", name: String? = nil, startTime: String? = nil, endTime: String? = nil, completion: ((String) -> Void)? = nil){
        var params = getParamsForVideoSDKNative()
        if comingFrom == "deeplink"{
            params["transaction_id"] = transaction_id
            params["request_token"] = 1
        }else{
            params["create_meet"] = 1
        }
        let url = URL(string: HippoCallClientUrl.baseUrl + "api/meet/videoSdkToken")!
        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = 60
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        print(params)
        switch enCodeType{
        case .json:
            if let body = try? JSONSerialization.data(withJSONObject: params, options: []) {
                urlRequest.httpBody = body
            }
        case .url:
            break
        }
        
        print("===== Req ====== \(urlRequest.httpMethod)\n \(urlRequest)")
        print("===== Param ======\n \(params.toJSONString())")
        let task = URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let data = data else {
                print(String(describing: error))
                return
            }
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data)
                if let dictionary = jsonObject as? [String: Any],
                   let results = dictionary["data"] as? [String: Any], let statusCode = dictionary["statusCode"] as? Int, (200...299).contains(statusCode) {
                    print(results)
                    self?.videoSdkToken = results["token"] as? String ?? ""
                    JitsiCallManager.shared.nativeMeetID = results["meeting_id"] as? String ?? ""
                    
                    print("token ------>>>>>>>", results["token"] as? String ?? "", "\n meeting id ---->>>>>", results["meeting_id"] as? String ?? "")
                    if comingFrom == "deeplink"{
                        DispatchQueue.main.async {
                            self?.joinVideoSdkCallByMeetingID(serverToken: results["token"] as? String ?? "", meetingID: results["meeting_id"] as? String ?? "", name: name, startTime: startTime, endTime: endTime)
                        }
                    }else{
                        if completion == nil{
                            DispatchQueue.main.async {
                                self?.joinVideoSdkCall()
                            }
                        }else{
                            completion?(params["transaction_id"] as? String ?? "")
                        }
                    }
                    
                }else{
                    if let jsonDict = jsonObject as? [String: Any], let msg = jsonDict["message"], let errorMsg = msg as? String{
                        self?.showAlert(with: errorMsg)
                    }
                }
            } catch {
                print("JSONSerialization error:", error)
            }
        }
        task.resume()
    }
    
    func getParamsForVideoSDKNative() -> [String : Any] {
        var params: [String: Any] = [:]
        
        if HippoCallClientUrl.shared.userType == .agent{
            params["access_token"] = HippoCallClientUrl.shared.agentToken
        }else{
            params["app_secret_key"] = HippoCallClientUrl.shared.appSecretKey ?? ""
        }
        
        
        if JitsiCallManager.shared.jitsiUrl?.isEmpty ?? true{
            params["transaction_id"] = JitsiCallManager.shared.randomString(length: 8)
        }else{
            params["transaction_id"] = JitsiCallManager.shared.jitsiUrl
        }
        
        return params
    }
    
    func handleCallEvent(for data: [String: Any], call: Call, jitsiSignal: JitsiCallSignal,isInviteEnabled: Bool) {
        
        JitsiCallManager.shared.activeCall?.signalingClient.signalReceivedFromPeer?(data)
        
        let jsonDict = data
        if let signal = jsonDict["video_call_type"] as? String, let signalType = JitsiCallSignal.JitsiSignalType(rawValue:signal) {
            HippoCallClient.shared.delgate?.didReceiveCallSignalType(signalType)
            print("handleCallEvent callClient 87", signalType,  CallClient.shared.currentDeviceID)
            if ((signalType == .HUNGUP_CONFERENCE || signalType == .REJECT_CONFERENCE) && call.isCallByMe ){
                JitsiCallManager.shared.otherUserCallHungup()
                return
            }else if signalType == .START_CONFERENCE_IOS {
                if let devicePayload = jsonDict["device_payload"] as? [String:Any], let deviceId = devicePayload["device_id"] as? String ,CallClient.shared.currentDeviceID != deviceId, call.currentUser.peerId != jitsiSignal.sender.peerId{
                    JitsiCallManager.shared.startReceivedCall(newCall: call, signal: jitsiSignal, isInviteEnabled: isInviteEnabled)
                } else if let deviceId = jsonDict["device_id"] as? String ,CallClient.shared.currentDeviceID != deviceId, call.currentUser.peerId != jitsiSignal.sender.peerId {
                    JitsiCallManager.shared.startReceivedCall(newCall: call, signal: jitsiSignal, isInviteEnabled: isInviteEnabled)
                }
                return
            }else if signalType == .START_GROUP_CALL {
                if let devicePayload = jsonDict["device_payload"] as? [String:Any], let deviceId = devicePayload["device_id"] as? String ,CallClient.shared.currentDeviceID != deviceId  {
                    JitsiCallManager.shared.startRecievedGroupCall(newCall: call, signal: jitsiSignal)
                } else if let deviceId = jsonDict["device_id"] as? String ,CallClient.shared.currentDeviceID != deviceId {
                    JitsiCallManager.shared.startRecievedGroupCall(newCall: call, signal: jitsiSignal)
                }
                return
            } else {
                JitsiCallManager.shared.addSignalReceiver()
            }
        }   else {
            print("FAILLLLLL")
        }
    }
    
    func userLoggedOut() {
        callPresenter?.remoteUserRejectedTheCall()
        callDisconnected()
    }
    
    func startConnecting(call: PresentCallRequest, uuid: String) {
        guard !isUserBusy(), credentials != nil else {
            print("Not Ready for Call. Try Again")
            return
        }
        loadCallPresenterView(uuid: uuid, defaultType: call.callType)
        
        //Check if callPresenter is given nil from service user
        guard callPresenter != nil else {
            return
        }
        
        registerCallHungupInCallPresenter()
        registerCallPresenterAccessories()
        callPresenter?.startConnectingCall(request: call, completion: {_ in })
    }
    
    private func shouldHandle(signal: CallSignal, call: Call) -> Bool {
        guard signal.senderDeviceID != currentDeviceID else {
            return false
        }
        guard signal.sender.peerId == call.currentUser.peerId else {
            return true
        }
        
        guard signal.signalType == .startCall || signal.signalType == .callHungUp || signal.signalType == .callRejected else {
            return false
        }
        
        return true
    }
    
    private func startPublishingLocalNotificationForIncomingCallWith(signal: CallSignal) {
        guard let call = activeCall, activeCall?.status == .idle || activeCall?.status == .incomingCall, signal.callUID == call.uID else {
            return
        }
        callPresenter?.addLocalIncomingCallNotification(peerName: call.peer.name, callType: signal.callType, identifier: call.uID)
        
        HippoDelay(5) {
            self.startPublishingLocalNotificationForIncomingCallWith(signal: signal)
        }
        
    }
    
    func startNew(call: Call, completion: @escaping (Bool) -> Void) {
        
        guard !isUserBusy(), call.signalingClient.checkIfReadyForCommunication(), credentials != nil else {
            print("Not Ready for Call. Try Again")
            return
        }
        
        activeCall = call
        
        loadCallPresenterView()
        
        //Check if callPresenter is given nil from service user
        guard callPresenter != nil else {
            return
        }
        registerActiveCallsSignallingClient()
        registerCallHungupInCallPresenter()
        registerCallPresenterAccessories()
        
        activeCall?.status = .outgoingCall
        
        let request = PresentCallRequest(peer: call.peer, callType: call.type, callUUID: call.uID)
        callPresenter?.startNewOutgoingCall(request: request) { [weak self] (success) in
            guard success, let weakSelf = self else {
                self?.callDisconnected()
                return
            }
            
            let signal = CallSignal(rtcSignal: [:], signalType: .startCall, callUID: call.uID, sender: call.currentUser, senderDeviceID: weakSelf.currentDeviceID, callType: call.type)
            self?.startTimerToExpireNotConnectedCallIn(signal: signal)
            self?.startSendingStartCallUntilItExpires(signal: signal, call: call)
        }
    }
    
    private func startSendingStartCallUntilItExpires(signal: CallSignal, call: Call) {
        guard let call = activeCall, call.uID == signal.callUID, call.status != .inCall else {
            return
        }
        
        if call.timeElapsedSinceCallStart > maxTimeInNotConnectedState {
            return
        }
        
        let json = self.credentials.toJson()
        self.sendSignalWith(json: json, signalType: .startCall, call: call)
        HippoDelay(2) {
            self.startSendingStartCallUntilItExpires(signal: signal, call: call)
        }
    }
    
    func sendStartCallSignal(call: Call) {
        let json = self.credentials.toJson()
        self.sendSignalWith(json: json, signalType: .startCall, call: call)
    }
    
    func hangupCall() {
        self.sendSignalWhenCallHungUp()
        self.callDisconnected()
    }
    
    func loadCallPresenterView(uuid: String = "", defaultType: Call.CallType = .audio) {
        guard self.callPresenter == nil else {
            return
        }
        let isDialedByUser  = activeCall?.status == Call.State.outgoingCall
        let idString = activeCall?.uID ?? uuid
        guard let id = UUID(uuidString: idString) else {
            return
        }
        let request = CallPresenterRequest.init(uuid: id, callType: activeCall?.type ?? defaultType, isDialedByUser: isDialedByUser)
        self.callPresenter =  HippoCallClient.shared.delgate?.loadCallPresenterView(request: request)
        registerPublishDataInCallPresenter()
    }
    
    // MARK: - Signal Handling
    private func takeActionOnSignalReceived(_ signal: CallSignal, forCall call: Call? = nil) {
        
        //      print("\n \nSignal Received: \(signal.signalType.rawValue) => \(signal.getJsonToSend()) \n \n")
        
        switch signal.signalType {
        case .startCall: //push
            if call != nil {
                startCallReceived(newCall: call!, signal: signal)
            }
            
        case .offer: //signal
            offerReceived(signal: signal)
            
        case .newIceCandidate: //signal
            newIceCandidatesReceived(signal: signal)
            
        case .readyToConnect: //signal
            readyToConnectReceived(signal: signal)
            
        case .answer: //signal
            answerReceived(signal: signal)
            
        case .callHungUp: //signal //push
            callHungupReceived(signal: signal)
            
        case .callRejected:
            callRejectReceived(signal: signal)
            
        case .userBusy: //push
            userBusyReceived(signal: signal)
        case .custom:
            if let customData = signal.customData {
                callPresenter?.newDataRecieved(data: customData)
            }
        }
    }
    
    private func startCallReceived(newCall: Call, signal: CallSignal) {
        if isUserBusy(), activeCall!.uID != newCall.uID { //user busy on another call
            sendSignalWith(json: [:], signalType: .userBusy, call: newCall)
            return
        }
        
        if activeCall == nil {
            activeCall = newCall
            registerActiveCallsSignallingClient()
        }
        
        startPublishingLocalNotificationForIncomingCallWith(signal: signal)
        sendReadyToConnectFor(signal: signal)
        startTimerToExpireNotConnectedCallIn(signal: signal)
    }
    
    private func sendReadyToConnectFor(signal: CallSignal) {
        guard let call = activeCall, call.status == .idle, signal.callUID == call.uID else {
            return
        }
        
        if call.status == .idle {
            let json = credentials.toJson()
            sendSignalWith(json: json, signalType: .readyToConnect, call: call)
        }
        
        HippoDelay(3) {
            self.sendReadyToConnectFor(signal: signal)
        }
    }
    
    private func startTimerToExpireNotConnectedCallIn(signal: CallSignal) {
        guard let call = activeCall, call.uID == signal.callUID, call.status != .inCall else {
            return
        }
        
        if call.timeElapsedSinceCallStart > maxTimeInNotConnectedState {
            expireActiveCall()
            return
        }
        
        HippoDelay(5) {
            call.timeElapsedSinceCallStart += 5
            self.startTimerToExpireNotConnectedCallIn(signal: signal)
        }
    }
    
    private func expireActiveCall() {
        guard let call = activeCall else {
            return
        }
        if shouldPostMissedCallNotificationFor(call: call) {
            postMissedCallNotificationFor(call: call)
        }
        
        if call.status == .outgoingCall {
            sendSignalWhenCallHungUp()
        }
        callPresenter?.remoteUserRejectedTheCall()
        callDisconnected()
    }
    
    private func postMissedCallNotificationFor(call: Call) {
        callPresenter?.addLocalMissedCallNotification(peerName: call.peer.name, callType: call.type, identifier: call.uID)
    }
    
    private func offerReceived(signal: CallSignal) {
        
        func isUserWaitingForOffer() -> Bool {
            guard isUserBusy(), activeCall!.uID == signal.callUID else {
                return false
            }
            return true
        }
        
        guard isUserWaitingForOffer() else {
            return
        }
        
        loadCallPresenterView()
        
        //Check if callPresenter is given nil from service user
        guard callPresenter != nil else {
            return
        }
        registerCallPresenterAccessories()
        registerCallAnsweredInCallPresenter()
        registerCallHungupInCallPresenter()
        
        if activeCall?.rtcClient == nil {
            let request = PresentCallRequest(peer: activeCall!.peer, callType: activeCall!.type, callUUID: activeCall!.uID)
            callPresenter?.reportIncomingCallWith(request: request) { [weak self] (success) in
                guard success, let weakSelf = self else {
                    return
                }
                
                weakSelf.activeCall?.rtcClient = WebRTCClient(delegate: weakSelf, credentials: weakSelf.credentials, isVoiceOnlyCall: weakSelf.activeCall!.type == .audio)
                weakSelf.activeCall?.status = .incomingCall
                weakSelf.activeCall?.rtcClient?.sdpReceivedFromSignalling(json: signal.rtcSignal)
            }
        } else {
            activeCall?.rtcClient?.sdpReceivedFromSignalling(json: signal.rtcSignal)
        }
        
    }
    
    private func callRejectReceived(signal: CallSignal) {
        guard let call = activeCall, call.uID == signal.callUID else {
            return
        }
        
        expireActiveCall()
    }
    
    private func shouldPostMissedCallNotificationFor(call: Call) -> Bool {
        return (call.status == .incomingCall || call.status == .idle) //&& call.type == .video
    }
    
    private func callHungupReceived(signal: CallSignal) {
        guard let call = activeCall, call.uID == signal.callUID else {
            return
        }
        
        if shouldPostMissedCallNotificationFor(call: call) {
            postMissedCallNotificationFor(call: call)
        }
        
        callPresenter?.remoteUserHungUp()
        callDisconnected()
    }
    
    private func newIceCandidatesReceived(signal: CallSignal) {
        guard signal.callUID == activeCall?.uID else {
            return
        }
        activeCall?.rtcClient?.candidateReceivedFromSignalling(json: signal.rtcSignal)
    }
    
    private func readyToConnectReceived(signal: CallSignal) {
        guard let call = activeCall, call.uID == signal.callUID, call.status == .outgoingCall else {
            return
        }
        
        if activeCall?.rtcClient == nil {
            activeCall?.rtcClient = WebRTCClient(delegate: self, credentials: credentials, isVoiceOnlyCall: call.type == .audio)
        }
        
        activeCall?.rtcClient?.startNewCall(completion: { (success) in
            if !success {
                print("RTC failed in Starting New Call ")
            }
        })
    }
    
    func userBusyReceived(signal: CallSignal) {
        guard let call = activeCall, call.uID == signal.callUID, call.status == .outgoingCall else {
            return
        }
        callPresenter?.userBusy()
        callDisconnected()
    }
    
    private func answerReceived(signal: CallSignal) {
        guard activeCall?.rtcClient != nil, activeCall?.uID == signal.callUID, activeCall?.status != .inCall else {
            return
        }
        
        activeCall?.status = .inCall
        activeCall?.rtcClient?.sdpReceivedFromSignalling(json: signal.rtcSignal)
        
        callPresenter?.callConnected()
    }
    
    //MARK: -
    private func registerCallPresenterAccessories() {
        
        registerPauseVideo()
        registerStartVideo()
        registerUnMuteButtonPressed()
        registerMuteButtonPressed()
        registerSwitchCameraInCallPresenter()
        registerLocalAndRemoteViewSwitchAction()
        registerChangeInVideoViewsFrameInCallPresenter()
        registerConfigurationOfAudioSessionInCallPresenter()
        registerAudioSessionActivationAndDeactivation()
        registerSpeakerSwitching()
    }
    private func registerPublishDataInCallPresenter() {
        callPresenter?.publishData = {[weak self] data in
            guard let weakSelf = self, let call = weakSelf.activeCall else {
                return
            }
            self?.sendSignalWith(json: [:], signalType: .custom, call: call, customData: data)
        }
    }
    
    private func registerPauseVideo() {
        callPresenter?.pauseVideoButtonPressed = { [weak self] in
            guard let rtcClient = self?.activeCall?.rtcClient else {
                return false
            }
            rtcClient.pauseVideo()
            return true
        }
    }
    
    private func registerStartVideo() {
        callPresenter?.startVideoButtonPressed = { [weak self] in
            guard let rtcClient = self?.activeCall?.rtcClient else {
                return false
            }
            rtcClient.startVideo()
            return true
        }
    }
    
    private func registerUnMuteButtonPressed() {
        callPresenter?.unMuteAudioButtonPressed = { [weak self] in
            guard let rtcClient = self?.activeCall?.rtcClient else {
                self?.callPresenter?.callMuted()
                return
            }
            
            rtcClient.unmuteAudio(completion: { (success) in
                if success {
                    self?.callPresenter?.callUnMuted()
                } else {
                    self?.callPresenter?.callMuted()
                }
            })
        }
    }
    
    private func registerMuteButtonPressed() {
        callPresenter?.muteAudioButtonPressed = { [weak self] in
            guard let rtcClient = self?.activeCall?.rtcClient else {
                self?.callPresenter?.callUnMuted()
                return
            }
            rtcClient.muteAudio(completion: { (success) in
                if success {
                    self?.callPresenter?.callMuted()
                } else {
                    self?.callPresenter?.callUnMuted()
                }
            })
        }
    }
    
    private func registerCallHungupInCallPresenter() {
        callPresenter?.callHungUp = { [weak self] in
            self?.hangupCall()
        }
    }
    
    private func registerCallAnsweredInCallPresenter() {
        callPresenter?.callAnswered = { [weak self] in
            self?.activeCall?.rtcClient?.incomingCallAnswered()
            self?.activeCall?.status = .inCall
            self?.callPresenter?.callConnected()
        }
    }
    
    private func registerSwitchCameraInCallPresenter() {
        callPresenter?.switchCameraButtonPressed = { [weak self] in
            guard let rtcClient = self?.activeCall?.rtcClient else {
                return false
            }
            rtcClient.switchCamera()
            return true
        }
    }
    
    private func registerLocalAndRemoteViewSwitchAction() {
        callPresenter?.switchRemoteAndLocalVideoViewButtonPressed = { [weak self] in
            self?.activeCall?.rtcClient?.localAndRemoteViewSwitched()
        }
    }
    
    private func registerChangeInVideoViewsFrameInCallPresenter() {
        callPresenter?.frameOfLocalVideoViewChanged = { [weak self] in
            self?.activeCall?.rtcClient?.frameOfLocalVideoContainerViewChanged()
        }
        
        callPresenter?.frameOfRemoteVideoViewChanged = { [weak self] in
            self?.activeCall?.rtcClient?.frameOfRemoteVideoContainerViewChanged()
        }
    }
    
    private func registerConfigurationOfAudioSessionInCallPresenter() {
        callPresenter?.configureAudioSession = {
            WebRTCClient.configureAudioSession()
        }
    }
    
    private func registerAudioSessionActivationAndDeactivation() {
        callPresenter?.audioSessionActivated = { audioSession in
            WebRTCClient.audioSessionDidActivate(audioSession)
        }
        
        callPresenter?.audioSessionDeactivated = { audioSession in
            WebRTCClient.audioSessionDidDeactivate(audioSession)
        }
    }
    
    private func registerSpeakerSwitching() {
        callPresenter?.setAudioOutputToSpeaker = { [weak self] (isSwitchingToSpeaker, completion) in
            guard let rtcClient = self?.activeCall?.rtcClient else {
                completion(false)
                return
            }
            
            rtcClient.changeAudioRouteToSpeaker(isSwitchingToSpeaker, completion: { (success) in
                completion(success)
            })
        }
    }
    
    private func callDisconnected() {
        activeCall?.rtcClient?.endCall()
        activeCall = nil
        callPresenter = nil
    }
    
    private func sendSignalWhenCallHungUp() {
        switch activeCall?.status ?? .idle {
        case .inCall:
            sendSignalWith(json: [:], signalType: .callHungUp, call: activeCall!)
        case .incomingCall:
            sendSignalWith(json: [:], signalType: .callRejected, call: activeCall!)
        case .outgoingCall:
            sendSignalWith(json: [:], signalType: .callHungUp, call: activeCall!)
        case .idle:
            break
        }
    }
    
    private func registerActiveCallsSignallingClient() {
        activeCall?.signalingClient.signalReceivedFromPeer = { [weak self] (jsonDict) in
            guard let signal = CallSignal.getFrom(json: jsonDict),
                  let weakSelf = self,
                  let call = weakSelf.activeCall,
                  weakSelf.shouldHandle(signal: signal, call: call) else {
                      return
                  }
            
            self?.takeActionOnSignalReceived(signal)
        }
    }
    
    func isUserBusy() -> Bool {
        return activeCall != nil
    }
    
    fileprivate func connectionLost() {
        callPresenter?.remoteUserHungUp()
        callDisconnected()
    }
    fileprivate func connectionRetry()  {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.callPresenter?.remoteRetryToConnect()
        }
    }
    
    fileprivate func connected() {
        callPresenter?.remoteConnected()
    }
}

// MARK: - WebRTC Client Delegate
extension CallClient: WebRTCClientDelegate {
    func viewForRenderingLocalVideo() -> UIView? {
        return callPresenter?.viewForLocalVideoRendering()
    }
    
    func viewForRenderingRemoteVideo() -> UIView? {
        return callPresenter?.viewForRemoteVideoRendering()
    }
    
    func sendOfferViaSignalling(json: [String : Any]) {
        callPresenter?.sendingOffer()
        sendSignalWith(json: json, signalType: .offer, call: activeCall!)
    }
    
    func sendAnswerViaSignalling(json: [String : Any]) {
        sendSignalWith(json: json, signalType: .answer, call: activeCall!)
    }
    
    func sendCandidateViaSignalling(json: [String : Any]) {
        sendSignalWith(json: json, signalType: .newIceCandidate, call: activeCall!)
    }
    
    func sendSignalWith(json: [String: Any], signalType: CallSignal.SignalType, call: Call, customData: CustomData? = nil) {
        var signal = CallSignal(rtcSignal: json, signalType: signalType, callUID: call.uID, sender: call.currentUser, senderDeviceID: currentDeviceID, callType: call.type)
        
        //For Sending multiole start call sliently
        signal.isForceSilent = call.isStartCallSend
        signal.customData = customData
        
        call.isStartCallSend = true
        
        call.signalingClient.connectClient(completion: { (success) in
            call.signalingClient.sendSignalToPeer(signal: signal, completion: { (success, error) in
                if !success {
                    NSLog("UNABLE TO SEND SIGNAL")
                    
                    if self.credentialRetry > 10 {
                        NSLog("Crendential retries expired to send signal")
                        self.credentialRetry = 0
                        return
                    }
                    
                    if let userInfo = error?.userInfo[NSLocalizedFailureReasonErrorKey] as? [String: Any],
                       let data = userInfo["data"] as? [String: Any],
                       let credential = CallClientCredential(rawCredentials: data) {
                        self.credentials = credential
                        self.credentialRetry += 1
                        self.sendSignalWith(json: credential.toJson(), signalType: signalType, call: call)
                    }
                    
                } else {
                    self.credentialRetry = 0
                    //               print("\n \n Signal Sent: \(signal.signalType.rawValue) => \(signal.getJsonToSend()) \n \n")
                }
            })
            
        })
    }
    
    func rtcConnectionDisconnected() {
        self.connectionLost()
    }
    
    func rtcConnectionRetry() {
        self.connectionRetry()
    }
    
    func rtcConnecetd() {
        self.connected()
    }
}

// MARK: - AVPermissionPopupView

private class AVPermissionPopupView: UIView {

    private let cardView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let settingsButton = UIButton(type: .custom)

    init(icon: String, title: String, message: String) {
        super.init(frame: UIScreen.main.bounds)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        setupCard(icon: icon, title: title, message: message)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCard(icon: String, title: String, message: String) {
        cardView.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)
        cardView.layer.cornerRadius = 16
        cardView.clipsToBounds = true
        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)

        iconImageView.image = UIImage(systemName: icon)
        iconImageView.tintColor = .systemBlue
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = .lightGray
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        settingsButton.setTitle("Open Settings", for: .normal)
        settingsButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        settingsButton.backgroundColor = .systemBlue
        settingsButton.setTitleColor(.white, for: .normal)
        settingsButton.layer.cornerRadius = 10
        settingsButton.clipsToBounds = true
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(openSettingsTapped), for: .touchUpInside)

        cardView.addSubview(iconImageView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(messageLabel)
        cardView.addSubview(settingsButton)

        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: 300),

            iconImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 28),
            iconImageView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            settingsButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24),
            settingsButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            settingsButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            settingsButton.heightAnchor.constraint(equalToConstant: 44),
            settingsButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -28),
        ])
    }

    func present() {
        guard superview == nil else { return }
        let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
        keyWindow?.addSubview(self)
    }

    @objc private func openSettingsTapped() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        removeFromSuperview()
    }
}





