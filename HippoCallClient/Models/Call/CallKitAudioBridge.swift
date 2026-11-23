//
//  CallKitAudioBridge.swift
//  HippoCallClient
//
//  Hands the audio session CallKit activates over to WebRTC.
//

import AVFoundation
import WebRTC
import os.log

private let callKitAudioLog = OSLog(subsystem: "com.hippo.callclient", category: "CallKitAudio")

protocol CallKitAudioSessionControlling: AnyObject {
    var useManualAudio: Bool { get set }
    var isAudioEnabled: Bool { get set }
    func configureForCall()
    func audioSessionDidActivate(_ session: AVAudioSession)
    func audioSessionDidDeactivate(_ session: AVAudioSession)
}

extension RTCAudioSession: CallKitAudioSessionControlling {
    func configureForCall() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .videoChat, options: [.allowBluetooth])
        } catch {
            os_log("configure failed: %{public}@", log: callKitAudioLog, type: .error, error.localizedDescription)
        }
    }
}

/// A call answered on the native CallKit screen gets its audio session from CallKit, and
/// after a VoIP relaunch nothing else has set the session up. WebRTC has to wait for
/// `provider(_:didActivate:)` before starting its audio unit, otherwise the microphone
/// can stay silent while remote audio still plays.
public final class CallKitAudioBridge {
    public static let shared = CallKitAudioBridge(session: RTCAudioSession.sharedInstance()) { delay, block in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block)
    }

    typealias Schedule = (TimeInterval, @escaping () -> Void) -> Void

    private static let activationTimeout: TimeInterval = 3

    private let session: CallKitAudioSessionControlling
    private let schedule: Schedule
    private let lock = NSLock()
    private var isWaitingForActivation = false
    private var isActivated = false
    private var answerID = 0

    init(session: CallKitAudioSessionControlling, schedule: @escaping Schedule) {
        self.session = session
        self.schedule = schedule
    }

    /// Call before fulfilling `CXAnswerCallAction`: CallKit activates audio after that.
    public func willAnswer() {
        lock.lock(); defer { lock.unlock() }
        answerID += 1
        isWaitingForActivation = true
        isActivated = false
        session.configureForCall()
        session.useManualAudio = true
        session.isAudioEnabled = false
        os_log("answer: waiting for CallKit audio", log: callKitAudioLog, type: .default)
    }

    /// Starts the deadline for `didActivate`, so a missing callback cannot leave the call silent.
    public func answerFulfilled() {
        lock.lock()
        let id = answerID
        lock.unlock()
        schedule(Self.activationTimeout) { [weak self] in
            self?.activationTimedOut(answerID: id)
        }
    }

    public func answerFailed() {
        reset()
    }

    public func didActivate(_ audioSession: AVAudioSession) {
        lock.lock(); defer { lock.unlock() }
        os_log("didActivate: category=%{public}@ mode=%{public}@ waiting=%{public}@", log: callKitAudioLog, type: .default,
               audioSession.category.rawValue, audioSession.mode.rawValue, "\(isWaitingForActivation)")
        guard isWaitingForActivation else { return }
        isWaitingForActivation = false
        isActivated = true
        session.audioSessionDidActivate(audioSession)
        session.isAudioEnabled = true
    }

    public func didDeactivate(_ audioSession: AVAudioSession) {
        lock.lock()
        let wasActivated = isActivated
        lock.unlock()
        if wasActivated {
            session.audioSessionDidDeactivate(audioSession)
        }
        reset()
    }

    /// The CallKit call ended. After activation, `didDeactivate` finishes the clean-up.
    public func callEnded() {
        lock.lock()
        let wasActivated = isActivated
        lock.unlock()
        if !wasActivated {
            reset()
        }
    }

    /// Returns WebRTC to automatic audio, as needed by meetings that do not use CallKit.
    public func reset() {
        lock.lock(); defer { lock.unlock() }
        resetLocked()
    }

    private func activationTimedOut(answerID id: Int) {
        lock.lock(); defer { lock.unlock() }
        guard id == answerID, isWaitingForActivation else { return }
        os_log("didActivate never arrived, using automatic audio", log: callKitAudioLog, type: .error)
        resetLocked()
    }

    private func resetLocked() {
        answerID += 1
        isWaitingForActivation = false
        isActivated = false
        session.isAudioEnabled = false
        session.useManualAudio = false
    }
}
