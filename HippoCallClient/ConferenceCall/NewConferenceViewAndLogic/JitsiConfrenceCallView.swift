//
//  ConfrenceCallView.swift
//  Fugu
//
//  Created by Rishi pal on 14/01/20.
//  Copyright © 2020 Fugu-Click Labs Pvt. Ltd. All rights reserved.
//

import UIKit
import JitsiMeetSDK
import AVFoundation


protocol JitsiConfrenceCallViewDelegate: class {
    func userDidJoinConference()
    func userWillLeaveConference()
    func userDidTerminatedConference()
    func userDidEnterPictureInPicture()
}

class JitsiConfrenceCallView: UIView {
    @IBOutlet var jitsiView: JitsiMeetView!
    @IBOutlet var view_JitsiTopView : UIView!
    @IBOutlet var label_Loading : UILabel!{
        didSet{
            label_Loading.text = HippoCallClientStrings.connectingToMeeting + " ..."
        }
    }
    
    static var shared: JitsiConfrenceCallView!
    weak var delegate: JitsiConfrenceCallViewDelegate?
    var player: AVAudioPlayer?
    fileprivate var pipViewCoordinator: PiPViewCoordinator?
    var loadingLabeltext : String?
    var displayLink : CADisplayLink?
    
    
    class func loadView(with frame: CGRect)-> JitsiConfrenceCallView? {
        if let view = Bundle.init(identifier: "org.cocoapods.HippoCallClient")?.loadNibNamed("JitsiConfrenceCallView", owner: nil, options: nil)?.first as? JitsiConfrenceCallView {
            view.frame = frame
            view.clipsToBounds = true
            NotificationCenter.default.addObserver(view,selector: #selector(handleURL),name: NSNotification.Name(rawValue: "SEND_URL_JITSI"), object: nil)
            return view
        }
        return nil
    }
    
    func setupJitsi(for data: JitsiMeetDataModel) {
        
        let userInfo =  JitsiMeetUserInfo(displayName: data.userName, andEmail: data.userEmail, andAvatar: data.userImage)
        let conferenceOptions =  JitsiMeetConferenceOptions.fromBuilder { (ptionsBuilder) in
            ptionsBuilder.setSubject(" ")
            ptionsBuilder.setAudioOnly(data.audioOnly)
            ptionsBuilder.serverURL = data.serverURL
            ptionsBuilder.room = data.roomID
            ptionsBuilder.setAudioMuted(data.isMuted)
            ptionsBuilder.userInfo = userInfo
            ptionsBuilder.setFeatureFlag("prejoinpage.enabled", withBoolean: false)
            ptionsBuilder.setFeatureFlag("welcomepage.enabled", withBoolean: false)
            ptionsBuilder.setFeatureFlag("chat.enabled", withValue: false)
            ptionsBuilder.setFeatureFlag("call-integration.enabled", withBoolean: true)
            ptionsBuilder.setFeatureFlag("pip.enabled", withBoolean: true)
            ptionsBuilder.setFeatureFlag("invite.enabled", withValue: data.isInviteEnabled)
            ptionsBuilder.setFeatureFlag("security-options.enabled", withValue: false)
            ptionsBuilder.setFeatureFlag("live-streaming.enabled", withBoolean: false)
            ptionsBuilder.setFeatureFlag("video-share.enabled", withBoolean: false)
            ptionsBuilder.setFeatureFlag("meeting-name.enabled", withBoolean: false)
            ptionsBuilder.setFeatureFlag("ios.screensharing.enabled", withValue: true)
        }
        
        print("room id ---->>>>", data.roomID, "\n server url --->>>>", data.serverURL)
        
        jitsiView.join(conferenceOptions)
        jitsiView.delegate = self
        animateLabelDots(label: label_Loading)
    }
    
    func setupPiP() {
        pipViewCoordinator = PiPViewCoordinator(withView: self)
        pipViewCoordinator?.delegate = self
        pipViewCoordinator?.configureAsStickyView()
    }
    
    
    func leaveConfrence(completion: @escaping(Bool)-> Void){
        self.jitsiView?.toggleScreenShare(false)
//        playSound(soundName: "disconnect_call", numberOfLoops: Int.max)
        DispatchQueue.main.async() { [weak self] in
            self?.jitsiView.leave()
            self?.stopPlayingSound()
            completion(true)
        }
    }
    
    func hideJitsiView(){
        self.isHidden = true
    }
    
    func showJitsiView(){
       self.isHidden = false
    }
    
    private func animateLabelDots(label: UILabel) {
        guard var text = label.text else { return }
        text = String(text.dropLast(3))
        loadingLabeltext = text
        displayLink = CADisplayLink(target: self, selector: #selector(showHideDots))
        displayLink?.add(to: .main, forMode: .common)
        displayLink?.preferredFramesPerSecond = 4
    }

    @objc private func showHideDots() {
        if !(loadingLabeltext?.contains("...") ?? false) {
            loadingLabeltext = loadingLabeltext?.appending(".")
        } else {
            loadingLabeltext = HippoCallClientStrings.connectingToMeeting
        }

        label_Loading.text = loadingLabeltext
    }
    
    @objc private func handleURL(notification: Notification) {
        if let userData = notification.userInfo, let url =  userData["url"] as? String{
            HippoCallClient.shared.createShareUrl(from: url)
        }
    }
    
    func removeNotification() {
        NotificationCenter.default.removeObserver(JitsiConfrenceCallView.shared, name: NSNotification.Name(rawValue: "SEND_URL_JITSI"), object: nil)
    }
}

extension JitsiConfrenceCallView : JitsiMeetViewDelegate {
    func conferenceJoined(_ data: [AnyHashable : Any]!) {
        delegate?.userDidJoinConference()
        view_JitsiTopView.isHidden = true
        displayLink?.invalidate()
        displayLink = nil
    }
    
    
    func conferenceTerminated(_ data: [AnyHashable : Any]!) {
        removeNotification()
        delegate?.userDidTerminatedConference()
        pipViewCoordinator?.exitPictureInPicture()
        pipViewCoordinator = nil
//        Logger.shared.printVar(for: data)
    }
    
    func enterPicture(inPicture data: [AnyHashable : Any]!) {
        setupPiP()
        delegate?.userDidEnterPictureInPicture()
        DispatchQueue.main.async {
            self.pipViewCoordinator?.enterPictureInPicture()
        }
    }
}

extension JitsiConfrenceCallView : PiPViewCoordinatorDelegate{
    
    func exitPictureInPicture() {
        pipViewCoordinator = nil
    }
}


//Sound logic
extension JitsiConfrenceCallView {
    func playSound(soundName: String, numberOfLoops: Int) {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") else { return }

        do {
//            if #available(iOS 14.5, *) {
//                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowAirPlay, .allowBluetoothA2DP, .mixWithOthers,.defaultToSpeaker, .interruptSpokenAudioAndMixWithOthers, .overrideMutedMicrophoneInterruption])
//            } else {
                // Fallback on earlier versions
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowAirPlay, .allowBluetoothA2DP, .mixWithOthers,.defaultToSpeaker])
//            }
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
       // Logger.shared.printVar(for: player)
        player?.pause()
        player?.stop()
        player = nil
       // Logger.shared.printVar(for: player)
    }
}

class JitsiMeetDataModel {
    let userName:  String?
    let userEmail: String?
    let userImage: URL?
    var audioOnly: Bool
    let serverURL: URL
    let roomID: String
    var isMuted : Bool
    var isInviteEnabled : Bool = false
    
    init(userName: String?, userEmail: String?, userImage: URL?, audioOnly: Bool, serverURl: URL, roomID: String, isMuted : Bool) {
        self.userName = userName
        self.userEmail = userEmail
        self.userImage =  userImage
        self.audioOnly = audioOnly
        self.serverURL = serverURl
        self.roomID = roomID
        self.isMuted = isMuted
    }
}
