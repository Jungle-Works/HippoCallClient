//
//  RecievedGroupCallView.swift
//  HippoCallClient
//
//  Created by Arohi Sharma on 20/07/20.
//  Copyright © 2020 Vishal. All rights reserved.
//

import UIKit
import AVFoundation


protocol RecievedGroupCallDelegate: class {
    func groupCallAnswered()
    func groupCallCancelled()
}


class RecievedGroupCallView: UIView {
    
    //MARK:- Variables
    static var shared: RecievedGroupCallView!
    var userInfo = [String : Any]()
    var player: AVAudioPlayer?
    weak var delegate: RecievedGroupCallDelegate?
    var callType : String?
    
    //IBOutlets
    @IBOutlet var ansButton: UIButton!
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var label_Calling: UILabel!
    @IBOutlet var label_Heading: UILabel!
    @IBOutlet var image_Conference : UIImageView!
    
   
    //MARK:- Load view
    class  func loadView()-> RecievedGroupCallView? {
        
        let view = Bundle.init(identifier: "org.cocoapods.HippoCallClient")?.loadNibNamed("RecievedGroupCallView", owner: nil, options: nil)?.first as? RecievedGroupCallView
        let frame =  UIApplication.shared.windows.first?.frame
        UIApplication.shared.windows.first?.endEditing(true)
        view?.frame = frame ?? .zero
        return view
    }
    
    //IBAction
    
    @IBAction func ansButtonTapped(_ sender: Any) {
        delegate?.groupCallAnswered()
    }
    
    @IBAction func cancelCallTapped(_ sender: Any) {
        delegate?.groupCallCancelled()
    }
}

extension RecievedGroupCallView {
    func remove() {
        stopPlayingSound()
        RecievedGroupCallView.shared.delegate = nil
        self.removeFromSuperview()
        RecievedGroupCallView.shared = nil
    }
    
    func setUp(){
        label_Calling.text = (userInfo["label"] as? String ?? "") + " " + String(format: HippoCallClientStrings.conferenceCallInvited, callType ?? "")
        ansButton.layer.cornerRadius = ansButton.frame.size.width/2
        cancelButton.layer.cornerRadius = cancelButton.frame.size.width/2
        image_Conference.layer.cornerRadius = image_Conference.frame.size.width/2
        ansButton.setImage(FuguImage.callAccept, for: .normal)
        cancelButton.setImage(FuguImage.callReject, for: .normal)
        label_Heading.font = FuguFont.titilliumWebSemiBold(with: 19)
        label_Calling.font = FuguFont.titilliumWebRegular(with: 17)
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
            if #available(iOS 14.5, *) {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowAirPlay, .allowBluetoothA2DP, .mixWithOthers,.defaultToSpeaker, .interruptSpokenAudioAndMixWithOthers, .overrideMutedMicrophoneInterruption])
            } else {
                // Fallback on earlier versions
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowAirPlay, .allowBluetoothA2DP, .mixWithOthers,.defaultToSpeaker, .interruptSpokenAudioAndMixWithOthers])
            }
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


