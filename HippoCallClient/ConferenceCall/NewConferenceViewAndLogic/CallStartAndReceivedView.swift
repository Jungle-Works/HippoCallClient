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
        // Keep the nib-loaded image if the runtime lookup fails (e.g. resource bundle
        // not resolvable) rather than blanking the button.
        if let accept = UIImage(named: "connectCall", in: self.bundle, compatibleWith: nil) ?? FuguImage.callAccept {
            ansButton.setImage(accept, for: .normal)
        }
        cancelButton.layer.cornerRadius = cancelButton.frame.height / 2
        cancelButton.layer.masksToBounds = true
        if let reject = UIImage(named: "disconnectCall", in: self.bundle, compatibleWith: nil) ?? FuguImage.callReject {
            cancelButton.setImage(reject, for: .normal)
        }
        userImageView.layer.cornerRadius = userImageView.frame.height / 2
        dailCallCancelButton.layer.cornerRadius = dailCallCancelButton.frame.height / 2
        dailCallCancelButton.layer.masksToBounds = true
        if let reject = UIImage(named: "disconnectCall", in: self.bundle, compatibleWith: nil) ?? FuguImage.callReject {
            dailCallCancelButton.setImage(reject, for: .normal)
        }
        userImageView.layer.borderWidth = 0.5
        userImageView.layer.borderColor = UIColor.lightGray.cgColor
        userImageView.layer.masksToBounds = true
        userImageView.contentMode = .scaleAspectFill
        let name = userInfo["label"] as? String
        nameLabel.text = name

        // Same as the conversation list / chat header: no photo -> show the name's
        // first letter (e.g. "V" for Visitor), not a generic placeholder / blank.
        // `URL(string: "")` is non-nil, so check for a real host before loading.
        let thumb = (userInfo["user_thumbnail_image"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        userImageView.image = CallStartAndReceivedView.initialsImage(for: name, size: userImageView.bounds.size)
        if !thumb.isEmpty, let url = URL(string: thumb), url.host != nil {
            userImageView.kf.setImage(with: url, placeholder: userImageView.image)
        }
    }

    /// Same per-initial pastel palette as the Hippo SDK's conversation list /
    /// chat header (FuguHelpers.material + getColor), duplicated here because those
    /// globals aren't visible from this module.
    private static let initialsPalette = [
        "B8E9F3", "D8C8FF", "C9E7CF", "FFD4B3", "FFCDDC",
        "FFEBA3", "C4EEEA", "DCC6F3", "C5E2FF", "CFF2DA"
    ]

    private static func color(fromHex hex: String) -> UIColor {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        return UIColor(red: CGFloat((value & 0xFF0000) >> 16) / 255,
                       green: CGFloat((value & 0x00FF00) >> 8) / 255,
                       blue: CGFloat(value & 0x0000FF) / 255,
                       alpha: 1)
    }

    /// Draws a circular avatar with the first letter of `name` on the palette colour
    /// for that letter — a self-contained stand-in for the SDK's `setTextInImage`.
    static func initialsImage(for name: String?, size: CGSize) -> UIImage? {
        let side = max(size.width, size.height, 60)
        let canvas = CGSize(width: side, height: side)
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let letter = trimmedName.isEmpty ? "?" : String(trimmedName.first!).uppercased()
        let idx = Int(letter.unicodeScalars.first?.value ?? 0) % initialsPalette.count
        let fill = color(fromHex: initialsPalette[idx])

        let renderer = UIGraphicsImageRenderer(size: canvas)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: canvas)
            fill.setFill()
            ctx.cgContext.fillEllipse(in: rect)
            let font = UIFont.systemFont(ofSize: side * 0.42, weight: .regular)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]
            let textSize = (letter as NSString).size(withAttributes: attrs)
            let textRect = CGRect(x: (side - textSize.width) / 2,
                                  y: (side - textSize.height) / 2,
                                  width: textSize.width,
                                  height: textSize.height)
            (letter as NSString).draw(in: textRect, withAttributes: attrs)
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
        ansButton.isHidden = true
        cancelButton.isHidden = true
        dailCallCancelButton.isHidden = false
        dailCallCancelButton.isEnabled = true
        callStateMessageLabel.text = HippoCallClientStrings.calling
    }

    func receivedCallSetup() {
        setup()
        // `CallStartAndReceivedView.shared` is a reused static instance — after an
        // outgoing call, dailCallSetup() has left receivedCallOptionView hidden, and
        // this method only reset the dial button. Explicitly restore the answer/
        // decline row so the decline button reappears on the next incoming call.
        receivedCallOptionView.isHidden = false
        ansButton.isHidden = false
        ansButton.isEnabled = true
        cancelButton.isHidden = false
        cancelButton.isEnabled = true
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
