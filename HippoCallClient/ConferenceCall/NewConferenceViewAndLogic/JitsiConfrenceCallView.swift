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
import WebRTC

protocol JitsiConfrenceCallViewDelegate: class {
    /// `join` has been requested; the conference has not come up yet.
    func userIsConnectingToConference()
    func userDidJoinConference()
    func userWillLeaveConference()
    func userDidTerminatedConference()
    /// Jitsi reported the conference ended. `error` is its `error` key, absent on a
    /// graceful hangup — see JitsiConnectionErrors.js / JitsiConferenceErrors.js.
    func conferenceDidTerminate(error: String?)
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
    private var pipDefaultDragInsets: UIEdgeInsets = .zero
    private var pipOriginBeforeKeyboard: CGPoint?

    
    class func loadView(with frame: CGRect)-> JitsiConfrenceCallView? {
        if let view = Bundle.init(identifier: "org.cocoapods.HippoCallClient")?.loadNibNamed("JitsiConfrenceCallView", owner: nil, options: nil)?.first as? JitsiConfrenceCallView {
            view.frame = frame
            view.clipsToBounds = true
            NotificationCenter.default.addObserver(view,selector: #selector(handleURL),name: NSNotification.Name(rawValue: "SEND_URL_JITSI"), object: nil)
            return view
        }
        return nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // The call screen sits on top of whatever was open (e.g. chat). Close that
        // screen's keyboard so it doesn't cover the call. Sent to nil so it reaches the
        // first responder in any window, not just this one.
        if window != nil {
            dismissKeyboard()
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func setupJitsi(for data: JitsiMeetDataModel) {
        
        #if DEBUG
        JitsiConsoleLogHandler.registerOnce()
        #endif
        let userInfo =  JitsiMeetUserInfo(displayName: data.userName, andEmail: data.userEmail, andAvatar: data.userImage)
        let conferenceOptions =  JitsiMeetConferenceOptions.fromBuilder { (ptionsBuilder) in
            ptionsBuilder.setSubject(" ")
            // Audio calls start with the camera muted, NOT in audio-only mode.
            // Audio-only stops this device from receiving/rendering remote video, so if
            // the other side turns its camera on mid-call it would never show here.
            // Must match Android (HippoCallConfig.java).
            ptionsBuilder.setAudioOnly(false)
            ptionsBuilder.setVideoMuted(data.audioOnly)
            ptionsBuilder.serverURL = data.serverURL
            ptionsBuilder.room = data.roomID
            //ptionsBuilder.setAudioMuted(data.isMuted)
            ptionsBuilder.userInfo = userInfo
            ptionsBuilder.setFeatureFlag("prejoinpage.enabled", withBoolean: false)
            ptionsBuilder.setFeatureFlag("welcomepage.enabled", withBoolean: false)
            ptionsBuilder.setFeatureFlag("chat.enabled", withValue: false)
            // call-integration MUST be disabled.
            // When enabled, Jitsi always fires CXStartCallAction(callUUID) which creates a
            // NEW outgoing CXCall. Our UUID is already registered as an incoming CXCall from
            // the VoIP push. iOS sees two incompatible CXCall states → providerDidReset →
            // CallKit screen dismissed. setCallUUID does NOT prevent this — Jitsi still calls
            // startCall internally regardless of whether the UUID exists.
            // With integration disabled: no Jitsi CallKit interference, our incoming CXCall
            // stays alive, audio session remains active, audio works via RTCAudioSession.
            ptionsBuilder.setFeatureFlag("call-integration.enabled", withBoolean: false)
            // Filmstrip is the small self-view tile in the corner during a video call.
            ptionsBuilder.setFeatureFlag("filmstrip.enabled", withBoolean: true)
            // 1:1 calls show only the self-view tile; the other person is already full screen.
            // Overrides the server's config.js in case it sets disable1On1Mode: true.
            ptionsBuilder.setConfigOverride("disable1On1Mode", withBoolean: false)
            ptionsBuilder.setFeatureFlag("pip.enabled", withBoolean: true)
            ptionsBuilder.setFeatureFlag("invite.enabled", withValue: data.isInviteEnabled)
            ptionsBuilder.setFeatureFlag("security-options.enabled", withValue: false)
            ptionsBuilder.setFeatureFlag("live-streaming.enabled", withBoolean: false)
            ptionsBuilder.setFeatureFlag("video-share.enabled", withBoolean: false)
            ptionsBuilder.setFeatureFlag("meeting-name.enabled", withBoolean: false)
            ptionsBuilder.setFeatureFlag("ios.screensharing.enabled", withValue: true)
            // Audio calls: no camera button, so the call stays audio-only for this user.
            ptionsBuilder.setFeatureFlag("video-mute.enabled", withBoolean: !data.audioOnly)
        }
        
        print("room id ---->>>>", data.roomID, "\n server url --->>>>", data.serverURL)

        jitsiView.delegate = self
        // Announced before join so the connect watchdog is armed even if the React Native
        // bridge is wedged and conferenceWillJoin never arrives.
        delegate?.userIsConnectingToConference()
        jitsiView.join(conferenceOptions)
        animateLabelDots(label: label_Loading)
    }
    
    func setupPiP() {
        pipViewCoordinator = PiPViewCoordinator(withView: self)
        pipViewCoordinator?.delegate = self
        pipViewCoordinator?.configureAsStickyView()
        pipDefaultDragInsets = pipViewCoordinator?.dragBoundInsets ?? .zero
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    /// The keyboard lives in its own window above the app, so the minimised call view
    /// would sit underneath it. While minimised, lift the view above the keyboard and stop
    /// it being dragged back under; put it back where it was when the keyboard closes.
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let coordinator = pipViewCoordinator, let container = superview,
              let endFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }

        let keyboardTop = container.convert(endFrame, from: nil).minY
        let keyboardHeight = max(0, container.bounds.maxY - keyboardTop)

        var insets = pipDefaultDragInsets
        insets.bottom += keyboardHeight
        coordinator.dragBoundInsets = insets

        var target = frame
        if keyboardHeight > 0 {
            let maxY = keyboardTop - pipDefaultDragInsets.bottom
            guard frame.maxY > maxY else { return }
            if pipOriginBeforeKeyboard == nil { pipOriginBeforeKeyboard = frame.origin }
            target.origin.y = max(container.safeAreaInsets.top + pipDefaultDragInsets.top, maxY - frame.height)
        } else if let original = pipOriginBeforeKeyboard {
            target.origin = original
            pipOriginBeforeKeyboard = nil
        } else {
            return
        }

        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        UIView.animate(withDuration: duration) { self.frame = target }
    }

    private func stopTrackingKeyboardForPiP() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        pipOriginBeforeKeyboard = nil
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
        // `self` is the observer loadView registered, and unlike the shared static it is
        // still valid here: conferenceTerminated arrives after teardown has already nilled
        // `shared`, and reading that implicitly unwrapped static would trap.
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "SEND_URL_JITSI"), object: nil)
    }
}

extension JitsiConfrenceCallView : JitsiMeetViewDelegate {
    func conferenceWillJoin(_ data: [AnyHashable : Any]!) {
        // Nothing to do beyond confirming the join actually started — the watchdog was
        // already armed in setupJitsi. If this never fires, the problem is before the
        // network: a bad room id / server URL, or a dead RN bridge.
    }

    func conferenceJoined(_ data: [AnyHashable : Any]!) {
        // call-integration.enabled is off (see setupJitsi), so Jitsi never gets a CallKit
        // activation callback to keep the AVAudioSession in .playAndRecord — its own join
        // sequence otherwise leaves the session on category .ambient, which cannot record.
        // JitsiAudioSession.activate(with:) alone does not restore the category, so set it
        // directly the same way HippoConfig.enableAudioSession() does for incoming calls,
        // then mirror providerDidActivateAudioSession's RTCAudioSession activation so
        // WebRTC's own audio unit actually starts.
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        JitsiAudioSession.activate(with: AVAudioSession.sharedInstance())
        RTCAudioSession.sharedInstance().useManualAudio = true
        RTCAudioSession.sharedInstance().audioSessionDidActivate(AVAudioSession.sharedInstance())
        RTCAudioSession.sharedInstance().isAudioEnabled = true
        delegate?.userDidJoinConference()
        view_JitsiTopView.isHidden = true
        displayLink?.invalidate()
        displayLink = nil
    }


    func conferenceTerminated(_ data: [AnyHashable : Any]!) {
        JitsiAudioSession.deactivate(with: AVAudioSession.sharedInstance())
        removeNotification()
        displayLink?.invalidate()
        displayLink = nil
        // `error` is only present when the conference failed; a graceful hangup omits it.
        delegate?.conferenceDidTerminate(error: data?["error"] as? String)
        stopTrackingKeyboardForPiP()
        pipViewCoordinator?.exitPictureInPicture()
        pipViewCoordinator = nil
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
        stopTrackingKeyboardForPiP()
        // Back to full screen: don't leave the chat keyboard covering the call.
        dismissKeyboard()
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
    var callUUID: UUID?

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

#if DEBUG
/// Jitsi's iOS SDK only emits logs to registered handlers — none are registered by
/// default, so nothing reaches the Xcode console. Debug builds only; filter on "[JITSI]".
final class JitsiConsoleLogHandler: JitsiMeetBaseLogHandler {
    static let shared = JitsiConsoleLogHandler()
    private static var isRegistered = false

    static func registerOnce() {
        guard !isRegistered else { return }
        isRegistered = true
        JitsiMeetLogger.add(shared)
    }

    override func logVerbose(_ msg: String!) { print("[JITSI][V]", msg ?? "") }
    override func logDebug(_ msg: String!) { print("[JITSI][D]", msg ?? "") }
    override func logInfo(_ msg: String!) { print("[JITSI][I]", msg ?? "") }
    override func logWarn(_ msg: String!) { print("[JITSI][W]", msg ?? "") }
    override func logError(_ msg: String!) { print("[JITSI][E]", msg ?? "") }
}
#endif
