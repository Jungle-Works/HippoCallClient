//
//  CallStartAndRevicedView.swift
//  Fugu
//
//  Created by Rishi pal on 14/01/20.
//  Copyright © 2020 Fugu-Click Labs Pvt. Ltd. All rights reserved.
//

import UIKit
import AVFoundation
import SafariServices

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
    
    var safariViewController: SFSafariViewController!
    static var shared :CallStartAndReceivedView!
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
        let frame =  UIApplication.shared.windows.first?.frame
        UIApplication.shared.windows.first?.endEditing(true)
        view?.frame = frame ?? .zero
        return view
    }
    
    fileprivate var bundle: Bundle? {

        let podBundle = Bundle(for: FuguImage.self)
        guard let bundleURL = podBundle.url(forResource: "HippoCallClient", withExtension: "bundle"), let fetchBundle = Bundle(url: bundleURL) else {
            return nil
        }
        return fetchBundle
    }
    
    func openSafariViewController(url:URL){
        
        var presentedVC: UIViewController?
        
        DispatchQueue.main.async {
            let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
            
            if var topController = keyWindow?.rootViewController {
                while let presentedViewController = topController.presentedViewController {
                    topController = presentedViewController
                }
                presentedVC = topController
                print("PRESNETED VIEW CONTROLLER ----->>>>> \(topController)")
                // topController should now be your topmost view controller
            }
            
            
            if presentedVC != self.safariViewController{
                self.safariViewController = SFSafariViewController(url: url)
                self.safariViewController.delegate = self
                
                self.getLastVisibleController()?.present(self.safariViewController, animated: true)
            }
            
        }
    }
    
    func getLastVisibleController(ofParent parent: UIViewController? = nil) -> UIViewController? {
        if let vc = parent {
            if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
                return getLastVisibleController(ofParent: selected)
            } else if let nav = vc as? UINavigationController, let top = nav.topViewController {
                return getLastVisibleController(ofParent: top)
            } else if let presented = vc.presentedViewController {
                return getLastVisibleController(ofParent: presented)
            } else {
                return vc
            }
        } else {
            if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                return getLastVisibleController(ofParent: rootVC)
            } else {
                return nil
            }
        }
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
//        cancelButton.setImage(UIImage(named: "disconnectCall"), for: .normal)
        cancelButton.setImage(UIImage(named: "disconnectCall", in: self.bundle, compatibleWith: nil), for: .normal)
        userImageView.layer.cornerRadius = userImageView.frame.height / 2
        dailCallCancelButton.layer.cornerRadius = dailCallCancelButton.frame.height / 2
        dailCallCancelButton.layer.masksToBounds = true
//        dailCallCancelButton.setImage(UIImage(named: "disconnectCall"), for: .normal)
        dailCallCancelButton.setImage(UIImage(named: "disconnectCall", in: self.bundle, compatibleWith: nil), for: .normal)
        userImageView.layer.borderWidth = 0.5
        userImageView.layer.borderColor = UIColor.lightGray.cgColor
        nameLabel.text = userInfo["label"] as? String
        let url =  URL(string: userInfo["user_thumbnail_image"] as? String ?? "")
        if let someUrl = url {
            userImageView.kf.setImage(with: someUrl)
        } else {
            userImageView.image = FuguImage.userImagePlaceholder
        }
        
    }
    
    @IBAction func ansButtonTapped(_ sender: Any) {
        JitsiCallManager.shared.userDidAnswered()
        print("click Answer Button")
    }
    
    @IBAction func cancelCallTapped(_ sender: Any) {
        print("click canceled call")
        JitsiCallManager.shared.userDidCanceled()
    }
    
    @IBAction func dailCallCanceled(_ sender: Any) {
        JitsiCallManager.shared.userDidCanceledDialCall()
        print("click canceled Dialed call")
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
        dailCallCancelButton.isEnabled = true
        callStateMessageLabel.text = HippoCallClientStrings.calling
    }
    
    func receivedCallSetup() {
        setup()
        dailCallCancelButton.isHidden = true
        dailCallCancelButton.isEnabled = false
        callStateMessageLabel.text = HippoCallClientStrings.callingYou
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
//            if #available(iOS 14.5, *) {
//                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowAirPlay, .allowBluetoothA2DP, .mixWithOthers,.defaultToSpeaker, .interruptSpokenAudioAndMixWithOthers, .overrideMutedMicrophoneInterruption])
//            } else {
                // Fallback on earlier versions
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowAirPlay, .allowBluetoothA2DP, .mixWithOthers,.defaultToSpeaker])
//            }
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


extension CallStartAndReceivedView: SFSafariViewControllerDelegate{
    
    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        print("url load successful")
    }

  
    func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL) {
        print(URL)
    }
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        // Dismiss the SafariViewController when done
        JitsiCallManager.shared.userDidTerminatedConference()
        self.remove()
    }
    
    func safariViewController(_ controller: SFSafariViewController, activityItemsFor URL: URL, title: String?) -> [UIActivity] {
        print(URL)
        let myActivity = MyActivity()
        return [myActivity]
    }
    
//    func safariViewControllerWillOpenInBrowser(_ controller: SFSafariViewController) {
//        print("good connection")
//    }
    
//    func safariViewController(_ controller: SFSafariViewController, excludedActivityTypesFor URL: URL, title: String?) -> [UIActivity.ActivityType] {
//        print(URL)
//        let myActivity = MyActivity()
//        return [myActivity.activityType()?.kf]
//    }
    
}


class MyActivity: UIActivity {

     func activityType() -> String? {
        return "MyActivity"
    }

    func activityImage() -> UIImage? {
        return nil
    }

     func activityTitle() -> String? {
        return "カスタマイズできた"
    }

     func canPerformWithActivityItems(activityItems: [AnyObject]) -> Bool {
        // Do something
        return true
    }

     func prepareWithActivityItems(activityItems: [AnyObject]) {
        // Do something
    }

    
}
