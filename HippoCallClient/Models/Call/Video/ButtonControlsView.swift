//
//  ButtonControlsView.swift
//  VideoSDK_Example
//
//  Created by VideoSDK Team on 13/09/21.
//  Copyright © 2021 Zujo Tech Pvt Ltd. All rights reserved.
//

import UIKit
import VideoSDKRTC

class ButtonControlsView: UIView {
    
    // MARK: - Buttons
    
    @IBOutlet weak var micButton: UIButton!
    @IBOutlet weak var videoButton: UIButton!
    @IBOutlet weak var leaveMeetingButton: UIButton!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var chatButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        setupUI()
    }
    
    // MARK: - Properties
    
    var onMicTapped: ((Bool) -> Void)?
    var onVideoTapped: ((Bool) -> Void)?
    var onEndMeetingTapped: (() -> Void)?
    var onMenuButtonTapped: (() -> Void)?
    var onCameraTapped: ((CameraPosition) -> Void)?
    var onChatButtonTapped: (() -> Void)?
    
    // handling for mic
    var micEnabled = true {
        didSet {
            updateMicButton()
        }
    }
    
    // handling for video
    var videoEnabled = true {
        didSet {
            updateVideoButton()
        }
    }
    
    // handling camera position
    var cameraPosition = CameraPosition.front {
        didSet {
            updateCameraButton()
        }
    }
    
    // Menu button
    var menuButtonEnabled: Bool = false {
        didSet {
            updateMenuButton()
        }
    }
    
    //Small red dot over messgae button
    lazy var unreadMessageView: UIView =  {
        let vw = UIView()
        vw.backgroundColor = UIColor.systemRed ?? UIColor.red
        return vw
    }()
    
    // Update Buttons
    func updateButtons(forStream stream: MediaStream, enabled: Bool) {
//        switch stream.kind {
//        case .video:
//            self.videoEnabled = enabled
//        case .audio:
//            self.micEnabled = enabled
//        default:
//            break
//        }
        switch stream.kind{
            
        case .share:
            break
        case .state(value: let value):
            switch value{
                
            case .audio:
                self.micEnabled = enabled
            case .video:
                self.videoEnabled = enabled
            }
        }
    }
    
    // MARK: - Actions
    
    @IBAction func micButtonTapped(_ sender: Any) {
        onMicTapped?(micEnabled)
    }
    
    @IBAction func leaveMeetingButtonTapped(_ sender: Any) {
        onEndMeetingTapped?()
    }
    
    @IBAction func videoButtonTapped(_ sender: Any) {
        onVideoTapped?(videoEnabled)
    }
    
    @IBAction func menuButtonTapped(_ sender: Any) {
        onMenuButtonTapped?()
    }
    
    @IBAction func cameraButtonTapped(_ sender: Any) {
        cameraPosition.toggle()
        onCameraTapped?(cameraPosition)
    }
    
    @IBAction func chatButtonTapped(_ sender: Any) {
        onChatButtonTapped?()
    }
    
}

extension ButtonControlsView {
    
    func setupUI() {
        self.layer.cornerRadius = 10
        
        updateMicButton()
        updateVideoButton()
        updateLeaveMeetingButton()
        updateMenuButton()
        updateCameraButton()
        updateChatButton()
        
        [micButton, videoButton, leaveMeetingButton, menuButton, cameraButton, chatButton].forEach {
            $0?.layer.cornerRadius = 8
            $0?.tintColor = .white
            $0?.heightAnchor.constraint(equalTo: $0!.widthAnchor, multiplier: 1.0).isActive = true
        }
    }
    
    func updateMicButton() {
        let imageName = micEnabled ? "mic_on" : "mic_off"
        let backgroundColor = micEnabled ? UIColor.systemGray : UIColor.systemRed
        micButton.setImage(UIImage(named: imageName, in: Bundle.init(identifier: "org.cocoapods.HippoCallClient"), compatibleWith: nil), for: .normal)
        micButton.backgroundColor = backgroundColor
    }
    
    func updateVideoButton() {
        let imageName = videoEnabled ? "camera_on" : "camera_off"
        let backgroundColor = videoEnabled ? UIColor.systemGray : UIColor.systemRed
        videoButton.setImage(UIImage(named: imageName, in: Bundle.init(identifier: "org.cocoapods.HippoCallClient"), compatibleWith: nil), for: .normal)
        videoButton.backgroundColor = backgroundColor
    }
    
    func updateLeaveMeetingButton() {
        leaveMeetingButton.setImage(UIImage(named: "call_end", in: Bundle.init(identifier: "org.cocoapods.HippoCallClient"), compatibleWith: nil), for: .normal)
        leaveMeetingButton.backgroundColor = UIColor.systemRed
    }
    
    func updateMenuButton() {
        let imageName = "more"
        let backgroundColor = !menuButtonEnabled ? UIColor.systemGray : UIColor.systemRed
        menuButton.setImage(UIImage(named: imageName, in: Bundle.init(identifier: "org.cocoapods.HippoCallClient"), compatibleWith: nil), for: .normal)
        menuButton.backgroundColor = backgroundColor
    }
    
    func updateCameraButton() {
        let imageName = "change_camera"
        let backgroundColor = UIColor.systemGray
        cameraButton.setImage(UIImage(named: imageName, in: Bundle.init(identifier: "org.cocoapods.HippoCallClient"), compatibleWith: nil), for: .normal)
        cameraButton.backgroundColor = backgroundColor
    }
    
    func updateChatButton() {
        let imageName = "chat"
        chatButton.setImage(UIImage(named: imageName, in: Bundle.init(identifier: "org.cocoapods.HippoCallClient"), compatibleWith: nil), for: .normal)
        chatButton.backgroundColor = UIColor.systemGray
        
        setDotViewOnMessageButton()
    }
    
    func setDotViewOnMessageButton(){
        
        self.chatButton.addSubview(unreadMessageView)
        unreadMessageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            
            self.unreadMessageView.heightAnchor.constraint(equalToConstant: 12),
            self.unreadMessageView.widthAnchor.constraint(equalTo: self.unreadMessageView.heightAnchor),
            self.unreadMessageView.bottomAnchor.constraint(equalTo: self.chatButton.topAnchor, constant: 4),
            self.unreadMessageView.trailingAnchor.constraint(equalTo: self.chatButton.trailingAnchor, constant: 4)
            
        ])
        self.unreadMessageView.layer.cornerRadius = 6
    }
}
