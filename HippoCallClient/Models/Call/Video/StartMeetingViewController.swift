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

    // MARK: - Mic level monitoring
    private let audioEngine = AVAudioEngine()
    private var isTestingAV = false

    // MARK: - Network indicator
    private let networkDot = UIView()
    private let networkLabel = UILabel()
   
    //Camera Capture requiered properties
    var videoDataOutput: AVCaptureVideoDataOutput!
    var videoDataOutputQueue: DispatchQueue!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var captureDevice: AVCaptureDevice!
    var rootLayer: CALayer!
    let session = AVCaptureSession()
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
        setupTestAudioVideoButton()
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
        setupNetworkIndicator()
    }

    // MARK: - Network Indicator

    private func setupNetworkIndicator() {
        // Dot
        networkDot.translatesAutoresizingMaskIntoConstraints = false
        networkDot.backgroundColor = .systemGray
        networkDot.layer.cornerRadius = 5
        NSLayoutConstraint.activate([
            networkDot.widthAnchor.constraint(equalToConstant: 10),
            networkDot.heightAnchor.constraint(equalToConstant: 10)
        ])

        // Label
        networkLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        networkLabel.textColor = .white
        networkLabel.text = "..."

        // Stack
        let stack = UIStackView(arrangedSubviews: [networkDot, networkLabel])
        stack.axis = .horizontal
        stack.spacing = 5
        stack.alignment = .center

        let networkBarItem = UIBarButtonItem(customView: stack)
        let cameraBarItem = UIBarButtonItem(customView: flipCameraButton)
        let audioBarItem = UIBarButtonItem(customView: switchAudioButton)
        // rightBarButtonItems are displayed right-to-left: latency | speaker | camera
        navigationItem.rightBarButtonItems = [networkBarItem, audioBarItem, cameraBarItem]

        // Start monitoring
        NetworkSpeedMonitor.shared.onUpdate = { [weak self] color, text in
            self?.networkDot.backgroundColor = color
            self?.networkLabel.text = text
        }
        NetworkSpeedMonitor.shared.start()
    }

    @objc private func backButtonTapped() {
        stopCamera()
        navigationController?.dismiss(animated: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        countdownTimer?.invalidate()
        countdownTimer = nil
        stopMicMonitoring()
        NetworkSpeedMonitor.shared.stop()
        valueOfVideoDevice = "Front Camera"
        valueOfAudioDevice = "Speaker"
    }

    // MARK: - Test Audio & Video

    private func setupTestAudioVideoButton() {
        viewTestAudioVideoContainer.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(testAudioVideoTapped))
        viewTestAudioVideoContainer.addGestureRecognizer(tap)
        updateTestButtonAppearance(testing: false)
    }

    private func updateTestButtonAppearance(testing: Bool) {
        UIView.animate(withDuration: 0.2) {
            self.viewTestAudioVideoContainer.backgroundColor = testing
                ? UIColor(red: 0.18, green: 0.72, blue: 0.35, alpha: 1)   // green
            : UIColor.red   // red
            self.viewTestAudioVideoContainer.layer.borderWidth = 0
        }
    }

    @objc private func testAudioVideoTapped() {
        isTestingAV.toggle()
        if isTestingAV {
            webCamEnabled = true
            updateVideoButton(status: true)
            previewLayer?.isHidden = false
            micEnabled = true
            updateAudioButton(status: true)
            startMicMonitoring()
        } else {
            webCamEnabled = false
            updateVideoButton(status: false)
            micEnabled = false
            updateAudioButton(status: false)
            stopMicMonitoring()
        }
        updateTestButtonAppearance(testing: isTestingAV)
    }

    private func startMicMonitoring() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            let level = self.rmsLevel(from: buffer)
            DispatchQueue.main.async { self.updateCameraBorder(level: level) }
        }

        viewCameraViewContainer.layer.borderWidth = 2.0

        do {
            try audioEngine.start()
        } catch {
            print("[Mic] AVAudioEngine failed to start: \(error)")
        }
    }

    private func stopMicMonitoring() {
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning { audioEngine.stop() }
        DispatchQueue.main.async {
            self.viewCameraViewContainer.layer.borderColor = UIColor.clear.cgColor
        }
    }

    private func rmsLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameCount = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameCount { sum += channelData[i] * channelData[i] }
        return frameCount > 0 ? sqrt(sum / Float(frameCount)) : 0
    }

    private func updateCameraBorder(level: Float) {
        guard micEnabled else {
            viewCameraViewContainer.layer.borderColor = UIColor.clear.cgColor
            return
        }
        let isSpeaking = level > 0.04
        viewCameraViewContainer.layer.borderColor = isSpeaking ? UIColor.systemGreen.cgColor : UIColor.clear.cgColor
    }

    // MARK: - Time Window

    enum MeetingWindowState: Equatable {
        case beforeStart
        case active
        case ended
    }

    static func windowState(start: Date, end: Date, now: Date = Date()) -> MeetingWindowState {
        if now > end { return .ended }
        if now < start { return .beforeStart }
        return .active
    }

    private func configureJoinButtonForTimeWindow() {
        guard let startStr = meetingStartTime, let endStr = meetingEndTime,
              let start = meetingDateFormatter.date(from: startStr),
              let end = meetingDateFormatter.date(from: endStr) else {
            return
        }
        switch StartMeetingViewController.windowState(start: start, end: end) {
        case .ended:
            print("[Meeting] Meeting has ended")
            //show popup meeting ended
            let alert = UIAlertController(title: nil,
                                          message: "The Video Chat has expired.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            setJoinButtonState(enabled: false, title: "Meeting Ended")
        case .beforeStart:
            setJoinButtonState(enabled: false, title: "")
            startCountdownTimer(to: start)
        case .active:
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
                self?.setJoinButtonState(enabled: false, title: "Joining...")
                self?.btnJoinAMeetingTapped(self as Any)
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
        if self.micEnabled {
            startMicMonitoring()
        } else {
            stopMicMonitoring()
        }
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
        stopMicMonitoring()
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
        flipCameraButton.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        flipCameraButton.tintColor = .systemBlue
        flipCameraButton.addTarget(self, action: #selector(flipCameraAction), for: .touchUpInside)
        flipCameraButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)

        switchAudioButton.setImage(UIImage(systemName: "speaker.wave.2"), for: .normal)
        switchAudioButton.tintColor = .systemBlue
        switchAudioButton.addTarget(self, action: #selector(switchAudioAction), for: .touchUpInside)
        switchAudioButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
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
        let effectiveDuration = remainingMeetingDuration()
        DispatchQueue.main.async {
            self.dismiss(animated: true) {
                CallClient.shared.joinMeeting(serverToken: self.serverToken, meetingID: self.txtMeetingCodeField.text ?? "", name: self.txtEnterNameField.text ?? "Guest", micEnabled: self.micEnabled, cameraEnabled: self.webCamEnabled, meetingDuration: effectiveDuration)
            }
        }
    }

    private func remainingMeetingDuration() -> TimeInterval {
        guard let endStr = meetingEndTime,
              let endDate = meetingDateFormatter.date(from: endStr) else { return 0 }
        let remaining = endDate.timeIntervalSinceNow
        return remaining > 0 ? remaining : 0
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
