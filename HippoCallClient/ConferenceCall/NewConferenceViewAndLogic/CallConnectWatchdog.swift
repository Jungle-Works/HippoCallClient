//
//  CallConnectWatchdog.swift
//  HippoCallClient
//
//  Fires once when a Jitsi conference fails to finish joining in time.
//

import Foundation

/// Deadline for the Jitsi join handshake.
///
/// Armed when `JitsiMeetView.join` is requested and disarmed on `conferenceJoined`.
/// If the deadline passes while still connecting the call is torn down, otherwise the
/// "Connecting to meeting..." view stays on screen forever — Jitsi exposes no way to
/// poll the connection state, so a deadline is the only way to detect the stall.
///
/// Deliberately free of UIKit, timers-on-self and singletons so the arm/disarm rules
/// can be unit tested with a fake scheduler. Public only so the test target can reach it.
public final class CallConnectWatchdog {

    /// Runs `block` after `delay` seconds and returns a closure that cancels it.
    public typealias Schedule = (_ delay: TimeInterval, _ block: @escaping () -> Void) -> () -> Void

    /// Used when the host app has not set `HippoCallClient.shared.callConnectTimeout`.
    public static let defaultTimeout: TimeInterval = 30

    /// Schedules on the main run loop in `.common` mode, so the deadline still fires
    /// while the user is dragging the PiP view around.
    public static let mainRunLoopSchedule: Schedule = { delay, block in
        let timer = Timer(timeInterval: delay, repeats: false) { _ in block() }
        RunLoop.main.add(timer, forMode: .common)
        return { timer.invalidate() }
    }

    /// `true` between `arm(timeout:onTimeout:)` and either the deadline firing or `disarm()`.
    public private(set) var isArmed = false

    private let schedule: Schedule
    private var cancelScheduled: (() -> Void)?

    public init(schedule: @escaping Schedule = CallConnectWatchdog.mainRunLoopSchedule) {
        self.schedule = schedule
    }

    /// Starts the deadline, replacing any deadline already running.
    ///
    /// - Parameter timeout: seconds to wait. Zero or less disables the watchdog entirely,
    ///   so `onTimeout` never runs.
    public func arm(timeout: TimeInterval, onTimeout: @escaping () -> Void) {
        disarm()
        guard timeout > 0 else { return }
        isArmed = true
        cancelScheduled = schedule(timeout) { [weak self] in
            guard let self = self, self.isArmed else { return }
            self.isArmed = false
            self.cancelScheduled = nil
            onTimeout()
        }
    }

    public func disarm() {
        cancelScheduled?()
        cancelScheduled = nil
        isArmed = false
    }

    deinit {
        disarm()
    }
}
