//
//  JitsiCallSignal.swift
//  Fugu
//
//  Created by Rishi pal on 15/01/20.
//  Copyright © 2020 Fugu-Click Labs Pvt. Ltd. All rights reserved.
//

import Foundation


import Foundation


struct JitsiCallSignal {
    // MARK: - Properties
    var signalType: JitsiSignalType
    let callUID: String
    let sender: CallPeer
    let senderDeviceID: String
    let callType: Call.CallType
    var conferenceLink: String?
    var hungUpType: HungupType?
    var isFSilent: Bool = true
    var shouldRefreshCall : Bool = false
    var transationID : String?
    var jitsiUrl : String
    
    init(signalType: JitsiSignalType, callUID: String, sender: CallPeer, senderDeviceID: String, callType: Call.CallType, link: String, isFSilent: Bool,transationID : String? = nil, jitsiUrl : String) {
        self.signalType = signalType
        self.callUID = callUID
        self.sender = sender
        self.senderDeviceID = senderDeviceID
        self.callType = callType
        self.isFSilent = isFSilent
        self.conferenceLink = link
        self.transationID = transationID
        self.jitsiUrl = jitsiUrl
    }
}

extension JitsiCallSignal {
    public enum JitsiSignalType: String {
        case START_CONFERENCE_IOS = "START_CONFERENCE_IOS"
        case START_CONFERENCE = "START_CONFERENCE"
        case READY_TO_CONNECT_CONFERENCE = "READY_TO_CONNECT_CONFERENCE"
        case READY_TO_CONNECT_CONFERENCE_IOS = "READY_TO_CONNECT_CONFERENCE_IOS"
        case HUNGUP_CONFERENCE = "HUNGUP_CONFERENCE"
        case USER_BUSY_CONFERENCE = "USER_BUSY_CONFERENCE"
        case OFFER_CONFERENCE = "OFFER_CONFERENCE"
        case ANSWER_CONFERENCE = "ANSWER_CONFERENCE"
        case REJECT_CONFERENCE = "REJECT_CONFERENCE"
        case START_GROUP_CALL = "START_GROUP_CALL"
        case REJECT_GROUP_CALL = "REJECT_GROUP_CALL"
        case JOIN_GROUP_CALL = "JOIN_GROUP_CALL"
        case END_GROUP_CALL = "END_GROUP_CALL"
        case CALL_HUNG_UP = "CALL_HUNG_UP"
    
    }
    
    enum HungupType: String {
        case `default` = "DEFAULT"
        case `switch` = "SWITCHED"
    }
    
    enum CallHungupReason: String {
        case otherUserNotPickCall = "Call not picked within 30 sec (iOS)"
        case mediaPremission = "Call disconnected by getUserMedia Error (iOS)"
        case switchedToConference = "Switched to conference call (iOS)"
        case hungupByUser = "call disconnected by user (iOS)"
        case wrtcDisconnected = "Ice connection status changed to disconnected (iOS)"
    }
    
}



// MARK: - Type Methods
extension JitsiCallSignal {
    static func getFrom(json: [String: Any]) -> JitsiCallSignal? {
        guard let rawSignalType = json["video_call_type"] as? String, let signalType = JitsiSignalType(rawValue: rawSignalType) else {
            return nil
        }
        
        let callUID = json["muid"] as? String ?? ""
                
        guard let user = HippoUser.init(json: json) else {
            print("User not intialized in Video Signal")
            return nil
        }
        
        var senderDeviceID = ""
        if let deviceID = (json["device_id"] as? String) {
            
            senderDeviceID = deviceID
        } else if let devicePayload = json["device_payload"] as? [String: Any], let deviceID = devicePayload["device_id"] as? String {
            senderDeviceID = deviceID
        }
        
        let callType: Call.CallType
        if let rawCallType = json["call_type"] as? String, let type = Call.CallType(rawValue: rawCallType) {
            callType = type
        } else {
            callType = .audio
        }
        
        let  invite_link = json["invite_link"] as? String ?? ""
        
        let jitsiUrl = json["jitsi_url"] as? String ?? ""
        
        var signalObj = JitsiCallSignal(signalType: signalType, callUID: callUID, sender: user, senderDeviceID: senderDeviceID, callType: callType, link: invite_link, isFSilent: false, jitsiUrl: jitsiUrl)
    
        if let rawHungupType = json["hungup_type"] as? String , let type = HungupType(rawValue: rawHungupType){
            signalObj.hungUpType = type
        }
        
//        Logger.shared.printVar(for: json["refresh_call"] as? Bool)
        if let transactionID = json["transaction_id"] as? String{
            signalObj.transationID = transactionID
        }
        
        return signalObj
    }
}

extension JitsiCallSignal {
    func getJsonToSendToFaye() -> [String : Any] {
        
        var fayeDict = [String: Any]()
        
        fayeDict["hungup_type"] =  HungupType.default.rawValue
        fayeDict["is_typing"] = 0
        fayeDict["user_id"] = Int(sender.peerId) ?? 0
        fayeDict["full_name"] = sender.name
        fayeDict["user_thumbnail_image"] = sender.image
        fayeDict["video_call_type"] = signalType.rawValue
        //      fayeDict["date_time"] = Date().convertToUTCFormat()
        fayeDict["message_type"] = "13"
        fayeDict["user_type"] = 1
        fayeDict["muid"] = callUID
        fayeDict["message"] = ""
        
        fayeDict["call_type"] = callType.rawValue
        fayeDict["jitsi_url"] = jitsiUrl
        
//        fayeDict["device_payload"] = [
//            "device_id": DeviceDetails.deviceId,
//            "device_type": 2,
//            "app_version": "212",
//            "device_details": DeviceDetails.getInDict()
//        ]
        
       // fayeDict["refresh_call"] = CallClient.shared.isRefreshCall
        
        fayeDict["is_silent"] = isFSilent
        fayeDict["invite_link"] = conferenceLink
        fayeDict["transaction_id"] = transationID
        
        return fayeDict
    }
}







