//
//  ConfrenceCallView.swift
//  Fugu
//
//  Created by Rishi pal on 14/01/20.
//  Copyright © 2020 Fugu-Click Labs Pvt. Ltd. All rights reserved.
//

import UIKit
import JitsiMeet
import AVFoundation

protocol JitsiConfrenceCallViewDelegate: class {
    func userDidJoinConference()
    func userWillLeaveConference()
    func userDidTerminatedConference()
    func userDidEnterPictureInPicture()
}

class JitsiConfrenceCallView: UIView {
    @IBOutlet var jitsiView: JitsiMeetView!
    static var shared: JitsiConfrenceCallView!
    weak var delegate: JitsiConfrenceCallViewDelegate?
    var player: AVAudioPlayer?
    
    class  func loadView(with frame: CGRect)-> JitsiConfrenceCallView? {
        let view = Bundle.main.loadNibNamed("JitsiConfrenceCallView", owner: nil, options: nil)?.first as? JitsiConfrenceCallView
        view?.frame = frame
        return view
    }
    
    func setupJitsi(for data: JitsiMeetDataModel) {
        
        let userInfo =  JitsiMeetUserInfo(displayName: data.userName, andEmail: data.userEmail, andAvatar: data.userImage)
        let conferenceOptions =  JitsiMeetConferenceOptions.fromBuilder { (ptionsBuilder) in
            ptionsBuilder.audioOnly = data.audioOnly
            ptionsBuilder.serverURL = data.serverURL
            ptionsBuilder.room = data.roomID
            ptionsBuilder.userInfo = userInfo
            ptionsBuilder.setFeatureFlag("chat.enabled", withValue: false)
            ptionsBuilder.setFeatureFlag("call-integration.enabled", withValue: false)
        }
        
        jitsiView.join(conferenceOptions)
//        if (JitsiCallManager.shared.link != nil){
//            self.updateConferenceCall(withLink: JitsiCallManager.shared.link)
//        }
        jitsiView.delegate = self
    }
    
    func leaveConfrence(completion: @escaping(Bool)-> Void){
        playSound(soundName: "disconnect_call", numberOfLoops: Int.max)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0) { [weak self] in
            self?.jitsiView.leave()
            self?.stopPlayingSound()
            completion(true)
        }
    }
    
//    func updateConferenceCall(withLink: String) {
//        var params = [String: Any]()
//        params["user_id_in_call"] = Workspace.current.user?.fuguUserId
//        params["calling_link"] = withLink
//        print("INVITE_LINK", withLink)
//        HTTPClient.makeConcurrentConnectionWith(method: .POST, para: params, extendedUrl: EndPoints.updateConferenceCall, isAccessTokenRequired: false, isAppVersionRequired: false, isDeviceDetailRequired: false) { (response, error, _, statusCode) in
//
//            guard let responseObject = response as? [String: Any] else {
//                return
//            }
//
//            print(responseObject)
//            let message = (responseObject["message"] as? String)
//            switch statusCode ?? 0 {
//            case STATUS_CODE_SUCCESS:
//                print("STATUS_CODE_SUCCESS", message)
//                break
//            default:
//                print("STATUS_CODE_NOT_SUCCESS", statusCode)
//                break
//            }
//        }
//    }
}

extension JitsiConfrenceCallView : JitsiMeetViewDelegate {
    func conferenceJoined(_ data: [AnyHashable : Any]!) {
        delegate?.userDidJoinConference()
//        Logger.shared.printVar(for: data)
    }
    
    func conferenceTerminated(_ data: [AnyHashable : Any]!) {
        delegate?.userDidTerminatedConference()
//        Logger.shared.printVar(for: data)
    }
    
    func enterPicture(inPicture data: [AnyHashable : Any]!) {
        delegate?.userDidEnterPictureInPicture()
//        Logger.shared.printVar(for: data)
    }
}


//Sound logic
extension JitsiConfrenceCallView {
    func playSound(soundName: String, numberOfLoops: Int) {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowAirPlay, .allowBluetoothA2DP, .mixWithOthers,.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            
            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
            
            guard let player = player else { return }
            player.numberOfLoops = numberOfLoops
            player.play()
            
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    func stopPlayingSound() {
//        Logger.shared.printVar(for: player)
        player?.pause()
        player?.stop()
        player = nil
//        Logger.shared.printVar(for: player)
    }
}

class JitsiMeetDataModel {
    let userName:  String?
    let userEmail: String?
    let userImage: URL?
    let audioOnly: Bool
    let serverURL: URL
    let roomID: String
    
    init(userName: String?, userEmail: String?, userImage: URL?, audioOnly: Bool, serverURl: URL, roomID: String) {
        self.userName = userName
        self.userEmail = userEmail
        self.userImage =  userImage
        self.audioOnly = audioOnly
        self.serverURL = serverURl
        self.roomID = roomID
    }
}
