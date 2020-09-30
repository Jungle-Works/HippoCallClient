//
//  Call.swift
//  HippoCallClient
//
//  Created by Vishal on 16/10/18.
//  Copyright © 2018 Fugu-Click Labs Pvt. Ltd. All rights reserved.
//

import Foundation

public class Call {
    var rtcClient: WebRTCClient?
    fileprivate(set) var signalingClient: SignalingClient
    public let peer: CallerInfo
    fileprivate(set) var currentUser: CallPeer
    public let uID: String
    var status = State.idle
    var timeElapsedSinceCallStart = 0
    let type: CallType
    var inviteLink: String = ""
    var isStartCallSend: Bool = false
    var isCallByMe: Bool = false
    var isGroupCall : Bool?
    var jitsiUrl : String
    
    public init(peer: CallPeer, signalingClient: SignalingClient, uID: String, currentUser: CallPeer, type: CallType, link: String, isGroupCall : Bool = false, jitsiUrl : String) {
        self.peer = peer
        self.signalingClient = signalingClient
        self.uID = uID
        self.currentUser = currentUser
        self.type = type
        self.inviteLink = link
        self.isGroupCall = isGroupCall
        self.jitsiUrl = jitsiUrl
    }
}

public class CallClientGroupCallData{
    var roomTitle : String?
    var roomUniqueId : String?
    var transactionId : String?
    var userType : String?
    var isMuted : Bool?
    
   
    public init(roomTitle : String, roomUniqueId : String, transactionId : String, userType : String, isMuted : Bool){
        self.roomTitle = roomTitle
        self.roomUniqueId = roomUniqueId
        self.transactionId = transactionId
        self.userType = userType
        self.isMuted = isMuted
    }
}


public extension Call {
    enum State {
        case idle //ready to connect not sent
        case incomingCall
        case inCall
        case outgoingCall
    }
    
    enum CallType: String {
        case audio = "AUDIO"
        case video = "VIDEO"
    }
}
