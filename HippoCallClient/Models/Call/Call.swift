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
    
    public init(peer: CallPeer, signalingClient: SignalingClient, uID: String, currentUser: CallPeer, type: CallType, link: String, isGroupCall : Bool = false) {
        self.peer = peer
        self.signalingClient = signalingClient
        self.uID = uID
        self.currentUser = currentUser
        self.type = type
        self.inviteLink = link
        self.isGroupCall = isGroupCall
        
    }
}

public class CallClientGroupCallData{
   var roomTitle : String?
   var roomUniqueId : String?
   
    public init(roomTitle : String, roomUniqueId : String){
        self.roomTitle = roomTitle
        self.roomUniqueId = roomUniqueId
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
