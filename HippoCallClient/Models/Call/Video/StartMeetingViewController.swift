//
//  StartMeetingViewController.swift
//  Pods
//
//  Created by Neha on 10/02/26.
//

import UIKit
import AVFoundation
import VideoSDKRTC

class StartMeetingViewController: UIViewController {
    
    // MARK: - Properties
    let meetingVC = MeetingViewController()
    var meetingID: String? = ""
    var serverToken = ""
    var micEnabled: Bool = false
    var webCamEnabled: Bool = false
    
    // MARK: - Outlets

    @IBOutlet weak var viewCameraViewContainer: UIView!
    @IBOutlet weak var viewAudioButton: UIView!
    @IBOutlet weak var imgAudioButton: UIImageView!
    @IBOutlet weak var imgVideoButton: UIImageView!
    @IBOutlet weak var viewVideoButton: UIView!
    @IBOutlet weak var viewTestAudioVideoContainer: UIView!
    @IBOutlet weak var viewCreateAMeetingButton: UIView!
    @IBOutlet weak var viewJoinAMeetingButton: UIView!
    @IBOutlet weak var txtEnterNameField: UITextField!
    @IBOutlet weak var viewEnterNameFieldContainer: UIView!
    @IBOutlet weak var viewJoinAMeetingView: UIView!
    @IBOutlet weak var txtMeetingCodeField: UITextField!
    @IBOutlet weak var viewMeetingCodeFieldContainer: UIView!
    
    @IBOutlet weak var btnVideoEnableDisable: UIButton!
    @IBOutlet weak var btnAudioEnableDisable: UIButton!
    @IBOutlet weak var btnJoinMeeting: UIButton!
    @IBOutlet weak var btnCreateMeeting: UIButton!
    @IBOutlet weak var btnJoinAMeeting: UIButton!
    
    @IBOutlet weak var joinAMeetingStackView: UIStackView!
    @IBOutlet weak var initialOptionStackView: UIStackView!
    
    @IBOutlet weak var joinAMeetingLabel: UILabel!
    // MARK: Properties

    var presetName: String? = nil
    var meetingStartTime: String? = nil
    var meetingEndTime: String? = nil
    private var countdownTimer: Timer?
    private let meetingDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return f
    }()

    var isJoinMeetingAction = true
    var isRequestInProgress = false
   
    //Camera Capture requiered properties
    var videoDataOutput: AVCaptureVideoDataOutput!
    var videoDataOutputQueue: DispatchQueue!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var captureDevice: AVCaptureDevice!
    var rootLayer: CALayer!
    let session = AVCaptureSession()
    var meetingDuration: TimeInterval = 0 * 60
    // MARK: - UI Elements
    let flipCameraButton = UIButton(type: .system)
    let switchAudioButton = UIButton(type: .system)

    @Published var valueOfVideoDevice: String? = "Front Camera"
    @Published var valueOfAudioDevice: String? = "Speaker"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareUI()
        addBackButton()
        VideoSDK.getAudioPermission()
        self.requestNotificationAuthorization()
        previewLayer?.isHidden = !self.webCamEnabled
    }

    private func addBackButton() {
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        backButton.tintColor = .white
        navigationItem.leftBarButtonItem = backButton
    }

    @objc private func backButtonTapped() {
        stopCamera()
        navigationController?.dismiss(animated: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        countdownTimer?.invalidate()
        countdownTimer = nil
        valueOfVideoDevice = "Front Camera"
        valueOfAudioDevice = "Speaker"
    }

    // MARK: - Time Window

    private func configureJoinButtonForTimeWindow() {
        guard let startStr = meetingStartTime, let endStr = meetingEndTime,
              let start = meetingDateFormatter.date(from: startStr),
              let end = meetingDateFormatter.date(from: endStr) else {
            return
        }
        let now = Date()
        if now > end {
            print("[Meeting] Meeting has ended")
            setJoinButtonState(enabled: false, title: "Meeting Ended")
        } else if now < start {
            setJoinButtonState(enabled: false, title: "")
            startCountdownTimer(to: start)
        } else {
            setJoinButtonState(enabled: true, title: "Join Meeting")
        }
    }

    private func setJoinButtonState(enabled: Bool, title: String) {
        btnJoinAMeeting.isEnabled = enabled
        btnJoinAMeeting.alpha = enabled ? 1.0 : 0.5
        joinAMeetingLabel.text = title
    }

    private func startCountdownTimer(to startTime: Date) {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            let remaining = startTime.timeIntervalSinceNow
            if remaining <= 0 {
                timer.invalidate()
                self?.setJoinButtonState(enabled: true, title: "Join Meeting")
            } else {
                let h = Int(remaining) / 3600
                let m = (Int(remaining) % 3600) / 60
                let s = Int(remaining) % 60
                let title = h > 0
                    ? String(format: "Starting in %02d:%02d:%02d", h, m, s)
                    : String(format: "Starting in %02d:%02d", m, s)
                print("[Countdown] \(title)")
                self?.setJoinButtonState(enabled: false, title: title)
            }
        }
        countdownTimer?.fire()
    }
    
    func prepareUI() {
        
        let attributes: [NSAttributedString.Key : Any] = [
            NSAttributedString.Key.foregroundColor : UIColor.gray
        ]
        viewCreateAMeetingButton.isHidden = true
        txtEnterNameField.attributedPlaceholder = NSAttributedString(string: "Enter your name", attributes: attributes)
        txtMeetingCodeField.attributedPlaceholder = NSAttributedString(string: "Enter meeting code", attributes: attributes)
        txtEnterNameField.delegate = self
        txtMeetingCodeField.delegate = self
        txtMeetingCodeField.text = meetingID

        if let name = presetName {
            txtEnterNameField.text = name
            txtEnterNameField.isUserInteractionEnabled = false
            txtEnterNameField.alpha = 0.6
        }

        if let mid = meetingID, !mid.isEmpty {
            txtMeetingCodeField.isUserInteractionEnabled = false
            txtMeetingCodeField.alpha = 0.6
            initialOptionStackView.isHidden = true
            joinAMeetingStackView.isHidden = false
        }

        configureJoinButtonForTimeWindow()
        
        [viewCameraViewContainer, viewJoinAMeetingButton, viewTestAudioVideoContainer].forEach {
            $0?.roundCorners(corners: [.allCorners], radius: 12.0)
        }
        
        viewTestAudioVideoContainer.layer.borderWidth = 1
        viewTestAudioVideoContainer.layer.borderColor = UIColor(named: "borderColor")?.cgColor
        
        [viewAudioButton, viewVideoButton].forEach{
            $0?.roundCorners(corners: [.allCorners], radius: 22.0)
        }
        
        [viewEnterNameFieldContainer, viewMeetingCodeFieldContainer, viewJoinAMeetingView].forEach{
            $0?.roundCorners(corners: [.allCorners], radius: 10.0)
        }
        
        setupAVCapture()
        configureCameraControls()
  
        updateVideoButton(status: self.webCamEnabled)
        updateAudioButton(status: self.micEnabled)
        
    }
    
    @IBAction func btnAudioEnableDisableTapped(_ sender: Any) {
        self.micEnabled = !self.micEnabled
        updateAudioButton(status: self.micEnabled)
    }
    
    @IBAction func btnVideoEnableDisableTapped(_ sender: Any) {
        self.webCamEnabled = !self.webCamEnabled
        updateVideoButton(status: self.webCamEnabled)
        previewLayer?.isHidden = !self.webCamEnabled
    }
    
    @IBAction func btnJoinMeetingTapped(_ sender: Any) {
        self.initialOptionStackView.isHidden = true
        self.joinAMeetingStackView.isHidden = false
        self.isJoinMeetingAction = true
        
     //   self.txtMeetingCodeField.becomeFirstResponder()
    }
    
    @IBAction func btnCreateMeetingTapped(_ sender: Any) {
        self.initialOptionStackView.isHidden = true
        self.joinAMeetingStackView.isHidden = false
        self.viewMeetingCodeFieldContainer.isHidden = true
        self.isJoinMeetingAction = false
        self.txtEnterNameField.becomeFirstResponder()
    }
    
    
    @IBAction func btnJoinAMeetingTapped(_ sender: Any) {
        stopCamera()
            guard !isRequestInProgress else { return }
            isRequestInProgress = true
            
            defer {
                // Reset the flag after execution
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.isRequestInProgress = false
                }
            }
            if isJoinMeetingAction {
                guard let meetingID = txtMeetingCodeField.text, !meetingID.isEmpty else {
                    self.showAlert(title: "Meeting ID Required", message: "Please provide a meeting ID to start the meeting.")
                    txtMeetingCodeField.resignFirstResponder()
                    return
                }
                joinMeeting()
            }
        }
    
    // MARK: - Actions
   @objc private func flipCameraAction() {
        showCameraOptions()
    }

        
   @objc private func switchAudioAction() {
        getAudioDeviceList()
    }
    
    func showCameraOptions() {
        if webCamEnabled == true {
            
            
            let cameras = ["Front Camera", "Back Camera"] // Predefined options
            
            DispatchQueue.main.async { [weak self] in
                self?.showDeviceSelectionAlert(devices: cameras,
                                               deviceType: "Camera",
                                               selectedDevice: self?.valueOfVideoDevice) { selectedCamera in
                    self?.valueOfVideoDevice = selectedCamera
                    self?.setupAVCapture()
                    self?.startCamera()
                }
            }
        }
        else
        {
            showAlert(title: "", message: "Turn on Camera first", autoDismiss: true)
        }
    }

        // MARK: - Get Audio Device List
        func getAudioDeviceList() {
            let audioDevices = VideoSDK.getAudioDevices()
            showDeviceSelectionAlert(devices: audioDevices,
                                    deviceType: "Audio Device",
                                    selectedDevice: valueOfAudioDevice) { selectedAudioDevice in
                self.valueOfAudioDevice = selectedAudioDevice
            }

        }

        // MARK: - Show Device Selection Alert
    func showDeviceSelectionAlert(devices: [String], deviceType: String, selectedDevice: String?, completion: @escaping (String) -> Void) {
        let alertController = UIAlertController(title: "Select \(deviceType)", message: nil, preferredStyle: .actionSheet)
        
        for device in devices {
            let action = UIAlertAction(title: device, style: .default) { _ in
                completion(device)
            }
            action.setValue(device == selectedDevice, forKey: "checked")
            alertController.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }

    func configureCameraControls() {
        
        // Add Flip Camera Button
        flipCameraButton.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        flipCameraButton.tintColor = .systemBlue
        flipCameraButton.addTarget(self, action: #selector(flipCameraAction), for: .touchUpInside)
        flipCameraButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(flipCameraButton) // Add to the main view, outside of the preview container
        
        // Add Switch Audio Button
        switchAudioButton.setImage(UIImage(systemName: "speaker.wave.2"), for: .normal)
        switchAudioButton.tintColor = .systemBlue
        switchAudioButton.addTarget(self, action: #selector(switchAudioAction), for: .touchUpInside)
        switchAudioButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(switchAudioButton) // Add to the main view, outside of the preview container
        
        // Apply Auto Layout Constraints
        NSLayoutConstraint.activate([
            // Flip Camera Button Constraints (Outside of the preview container)
            flipCameraButton.leadingAnchor.constraint(equalTo: view.trailingAnchor, constant: -100),
            flipCameraButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 60),
            flipCameraButton.widthAnchor.constraint(equalToConstant: 40),
            flipCameraButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Switch Audio Button Constraints (Outside of the preview container)
            switchAudioButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -19),
            switchAudioButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 60),
            switchAudioButton.widthAnchor.constraint(equalToConstant: 40),
            switchAudioButton.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private func getSelectedCameraPosition() -> AVCaptureDevice.Position? {
        switch valueOfVideoDevice {
        case "Front Camera":
            return .front
        case "Back Camera":
            return .back
        default:
            return .front
        }
    }
    
    func updateAudioButton(status: Bool) {
        self.viewAudioButton.backgroundColor = status ? UIColor.white : UIColor.red
        self.imgAudioButton.image = status ? UIImage(systemName: "mic.fill") : UIImage(systemName: "mic.slash.fill")
        self.imgAudioButton.tintColor = status ? UIColor.black : UIColor.white
    }
    
    func updateVideoButton(status: Bool) {
        self.viewVideoButton.backgroundColor = status ? UIColor.white : UIColor.red
        self.imgVideoButton.image = status ? UIImage(systemName: "video.fill") : UIImage(systemName: "video.slash.fill")
        self.imgVideoButton.tintColor = status ? UIColor.black : UIColor.white
        self.viewCameraViewContainer.backgroundColor = UIColor.black 
        status ? self.startCamera() : self.stopCamera()
    }
    
    // MARK: - Actions
    
    func joinMeeting() {
        txtEnterNameField.resignFirstResponder()
        
        if !serverToken.isEmpty {
            // use provided token for the meeting
            self.startMeeting()
        }else {
            // show error popup
            self.showAlert(title: "Auth Token Required", message: "Please provide auth token to start the meeting.")
        }
    }
    
    // MARK: - Navigation
    
    func startMeeting() {
        DispatchQueue.main.async {
            self.dismiss(animated: true) {
                CallClient.shared.joinMeeting(serverToken: self.serverToken, meetingID: self.txtMeetingCodeField.text ?? "", name: self.txtEnterNameField.text ?? "Guest", micEnabled: self.micEnabled, cameraEnabled: self.webCamEnabled, meetingDuration:self.meetingDuration )
            }
        }
    }
}

extension StartMeetingViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        if textField == txtMeetingCodeField {
            txtEnterNameField.becomeFirstResponder()
        }
        return true
    }
}


extension StartMeetingViewController: AVCaptureVideoDataOutputSampleBufferDelegate{
    
    func setupAVCapture() {
        session.stopRunning()
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        
        guard let facingMode = getSelectedCameraPosition() else { return }

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: facingMode
        ) else {
            return
        }

        captureDevice = device
        beginSession()
    }


    func beginSession(){
        var deviceInput: AVCaptureDeviceInput!
        do {
            deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            guard deviceInput != nil else {
                print("error: cant get deviceInput")
                return
            }

            if self.session.canAddInput(deviceInput){
                self.session.addInput(deviceInput)
            }

            videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
            videoDataOutput.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue)

            if session.canAddOutput(self.videoDataOutput){
                session.addOutput(self.videoDataOutput)
            }

            videoDataOutput.connection(with: .video)?.isEnabled = true

            previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
            previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            
            previewLayer.frame = viewCameraViewContainer.bounds
            previewLayer.cornerRadius = 12.0
            self.viewCameraViewContainer.layer.addSublayer(self.previewLayer)
        } catch let error as NSError {
            deviceInput = nil
            print("error: \(error.localizedDescription)")
        }
    }
    
    func startCamera() {
        // Start the camera session on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
            [viewVideoButton, viewAudioButton].forEach {
                       viewCameraViewContainer.bringSubviewToFront($0)
        }
    }

    // clean up AVCapture
    func stopCamera(){
        if session.isRunning {
               session.stopRunning()
            previewLayer?.isHidden = true
            updateVideoButton(status: false)
                
           }
    }
    
    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: UNAuthorizationOptions.init(arrayLiteral: .alert, .badge, .sound)) { (success, error) in
            if let error = error {
                print("requestAuthorization error: ", error)
            }
        }
    }

}
