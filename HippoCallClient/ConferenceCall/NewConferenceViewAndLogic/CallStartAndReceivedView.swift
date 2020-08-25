//
//  CallStartAndRevicedView.swift
//  Fugu
//
//  Created by Rishi pal on 14/01/20.
//  Copyright © 2020 Fugu-Click Labs Pvt. Ltd. All rights reserved.
//

import UIKit
import AVFoundation

//import Kingfisher

protocol CallStartAndReceivedViewDelegate: class {
    func userDidAnswered()
    func userDidCanceled()
    func userDidCanceledDialCall()
}

class CallStartAndReceivedView: UIView {
    
    @IBOutlet var callTypeMessageButton: UIButton!
    @IBOutlet var userImageView: UIImageView!
    @IBOutlet var ansButton: UIButton!
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var dailCallCancelButton: UIButton!
    @IBOutlet var callStateMessageLabel: UILabel!
    @IBOutlet var receivedCallOptionView: UIView!
    
    static var shared: CallStartAndReceivedView!
    var userInfo = [String : Any]()
    var isCallRecieved : Bool?
    
    var callStateText =  HippoCallClientStrings.calling.capitalizingFirstLetter() {
        didSet{
            callStateMessageLabel.text = callStateText
        }
    }
    
    var player: AVAudioPlayer?
    weak var delegate: CallStartAndReceivedViewDelegate?
    
    enum ViewType {
        case receive
        case dial
    }

    class  func loadView()-> CallStartAndReceivedView? {
        
        let view = Bundle.init(identifier: "org.cocoapods.HippoCallClient")?.loadNibNamed("CallStartAndReceivedView", owner: nil, options: nil)?.first as? CallStartAndReceivedView
        let frame =  UIApplication.shared.keyWindow?.frame
        UIApplication.shared.keyWindow?.endEditing(true)
        view?.frame = frame ?? .zero
        return view
    }
    
    
    func setup() {
        nameLabel.font = FuguFont.titilliumWebSemiBold(with: 19)
        nameLabel.textColor = UIColor.iLightBlack
        callStateMessageLabel.font = FuguFont.titilliumWebRegular(with: 17)
        callStateMessageLabel.textColor = UIColor.iLightBlack
        ansButton.layer.cornerRadius = ansButton.frame.height / 2
        ansButton.layer.masksToBounds = true
         ansButton.setImage(UIImage(named: "connectCall"), for: .normal)
        cancelButton.layer.cornerRadius = cancelButton.frame.height / 2
        cancelButton.layer.masksToBounds = true
        cancelButton.setImage(UIImage(named: "disconnectCall"), for: .normal)

        userImageView.layer.cornerRadius = userImageView.frame.height / 2
        dailCallCancelButton.layer.cornerRadius = dailCallCancelButton.frame.height / 2
        dailCallCancelButton.layer.masksToBounds = true
        dailCallCancelButton.setImage(UIImage(named: "disconnectCall"), for: .normal)

        userImageView.layer.borderWidth = 0.5
        userImageView.layer.borderColor = UIColor.lightGray.cgColor
        nameLabel.text = userInfo["label"] as? String
        let url =  URL(string: userInfo["user_thumbnail_image"] as? String ?? "")
        if let someUrl = url, someUrl != nil {
            userImageView.kf.setImage(with: someUrl)
        } else {
            userImageView.image = FuguImage.userImagePlaceholder
        }
    }
    
    @IBAction func ansButtonTapped(_ sender: Any) {
        delegate?.userDidAnswered()
    }
    
    @IBAction func cancelCallTapped(_ sender: Any) {
        delegate?.userDidCanceled()
    }
    @IBAction func dailCallCanceled(_ sender: Any) {
        //delegate?.userDidCanceledDialCall()
//        remove()
    }
    
}

//Remove logic
extension CallStartAndReceivedView {
    func remove() {
        stopPlayingSound()
        CallStartAndReceivedView.shared.delegate = nil
        self.removeFromSuperview()
        CallStartAndReceivedView.shared = nil
    }
    
    func showUserBusy(With message: String , completion: @escaping(Bool)-> Void) {
        playUserBusySound()
        dailCallCancelButton.isEnabled = false
        callStateMessageLabel.text = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            completion(true)
        }
    }
}


extension CallStartAndReceivedView {
    func dailCallSetup() {
        setup()
        receivedCallOptionView.isHidden = true
        callStateMessageLabel.text = HippoCallClientStrings.calling.capitalizingFirstLetter()
    }
    
    func receivedCallSetup() {
        setup()
        dailCallCancelButton.isHidden = true
        callStateMessageLabel.text = HippoCallClientStrings.callingYou.capitalizingFirstLetter()
    }
    
    func playDailCallSound() {
       playSound(soundName: "ringing", numberOfLoops: Int.max)
    }
    
    func playUserBusySound() {
         playSound(soundName: "call_busy", numberOfLoops: Int.max)
    }
    
    func playReceivedCallSound() {
        playSound(soundName: "incoming_call", numberOfLoops: Int.max)
    }
    
    func stopPlayingSound() {
//        Logger.shared.printVar(for: player)
        player?.pause()
        player?.stop()
        player = nil
//        Logger.shared.printVar(for: player)
    }
    
    func playSound(soundName: String, numberOfLoops: Int) {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowAirPlay, .allowBluetoothA2DP, .mixWithOthers,.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
            
            guard let player = player else { return }
            player.numberOfLoops = numberOfLoops
            player.play()
            
        } catch let error {
            print(error.localizedDescription)
        }
    }

}


