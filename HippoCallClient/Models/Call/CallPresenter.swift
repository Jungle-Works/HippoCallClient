//
//  CallPresenter.swift
//  OfficeChat
//
//  Created by Asim on 16/10/18.
//  Copyright © 2018 Fugu-Click Labs Pvt. Ltd. All rights reserved.
//

import UIKit
import AVFoundation

public struct CallPresenterRequest {
    public let uuid: UUID
    public let callType: Call.CallType
    public let isDialedByUser: Bool
}

public protocol CallPresenter: class {
   var callAnswered: (() -> Void)? { get set }
   var callHungUp: (() -> Void)? { get set }
   
   var muteAudioButtonPressed: (() -> Void)? { get set }
   var unMuteAudioButtonPressed: (() -> Void)? { get set }
   var pauseVideoButtonPressed: (() -> Bool)? { get set }
   var startVideoButtonPressed: (() -> Bool)? { get set }
   var switchCameraButtonPressed: (() -> Bool)? { get set }
   var switchRemoteAndLocalVideoViewButtonPressed: (() -> Void)? { get set }
   var frameOfRemoteVideoViewChanged: (() -> Void)? { get set }
   var frameOfLocalVideoViewChanged: (() -> Void)? { get set }
   
   var configureAudioSession: (() -> Void)? {get set}
   var audioSessionDeactivated: ((AVAudioSession) -> Void)? {get set}
   var audioSessionActivated: ((AVAudioSession) -> Void)? {get set}
   
   var setAudioOutputToSpeaker: ((Bool, @escaping (Bool) -> Void) -> Void)? {get set}
   
   func reportIncomingCallWith(request: PresentCallRequest, completion: @escaping (Bool) -> Void)
   func startNewOutgoingCall(request: PresentCallRequest, completion: @escaping (Bool) -> Void)
   func callConnected()
   func remoteUserRejectedTheCall()
   func remoteUserHungUp()
   func userBusy()
   
   
   func viewForLocalVideoRendering() -> UIView?
   func viewForRemoteVideoRendering() -> UIView?
   
   func callMuted()
   func callUnMuted()
    
   func startConnectingCall(request: PresentCallRequest, completion: @escaping (Bool) -> Void)
    
    func addLocalIncomingCallNotification(peerName: String, callType: Call.CallType, identifier: String)
    func addLocalMissedCallNotification(peerName: String, callType: Call.CallType, identifier: String)
}

public struct PresentCallRequest {
    public let peer: CallerInfo
    public let callType: Call.CallType
    
    
    public init(peer: CallerInfo, callType: Call.CallType) {
        self.peer = peer
        self.callType = callType
    }
}
