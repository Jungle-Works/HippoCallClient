//
//  FinishedCallLedger.swift
//  HippoCallClient
//
//  Remembers which calls are already over, so a late push cannot revive them.
//

import Foundation

/// Short-lived memory of the muids of calls that have already ended on this device.
///
/// CallKit calls are created straight from the VoIP push (`reportIncomingCallOnCallKit`),
/// which knows nothing about call state, while every teardown path is keyed on the live
/// `activeCall`. Once a call is torn down `activeCall` is nil and its CXCall has been ended,
/// so both guards in the push handler — `checkIfUserIsBusy` and `hasActiveCallForUUID` —
/// go back to `false` for that same muid. A push arriving after that (a repeated
/// `START_CONFERENCE_IOS` from the caller, or the backend's call-ended push) then reports a
/// *new* incoming CXCall, and `startReceivedCall` immediately drops it on `idForHungUpSent`,
/// so no call state exists to ever end it again. The CallKit screen stays up forever.
///
/// This ledger is the missing memory: the CallKit teardown records the muid and the push
/// handler refuses to resurrect it.
///
/// Entries expire and the ledger is capped, so a long session cannot grow it without bound
/// and a stale muid can never permanently block a genuine call — the backend does not reuse
/// muids, but silently swallowing a real call would be worse than a stray CallKit screen.
///
/// Deliberately free of UIKit, timers and singletons so the rules can be unit tested with a
/// fake clock. Public only so the test target can reach it.
public final class FinishedCallLedger {

    /// Reads the current time. Injected so tests can move the clock without sleeping.
    public typealias Now = () -> Date

    /// How long a finished muid keeps blocking new CallKit reports.
    public static let defaultEntryLifetime: TimeInterval = 300

    /// Most muids kept at once. Oldest are dropped first.
    public static let defaultCapacity = 32

    private let entryLifetime: TimeInterval
    private let capacity: Int
    private let now: Now
    /// Oldest first, so pruning is a prefix drop.
    private var entries: [(uid: String, finishedAt: Date)] = []
    private let lock = NSLock()

    public init(entryLifetime: TimeInterval = FinishedCallLedger.defaultEntryLifetime,
                capacity: Int = FinishedCallLedger.defaultCapacity,
                now: @escaping Now = { Date() }) {
        self.entryLifetime = entryLifetime
        self.capacity = capacity
        self.now = now
    }

    /// Records that this call is over. Nil and empty uids are ignored — a teardown that
    /// could not name its call has nothing useful to remember.
    public func markFinished(_ uid: String?) {
        guard let uid = uid, !uid.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll { $0.uid == uid }
        entries.append((uid: uid, finishedAt: now()))
        prune()
    }

    /// `true` while a finished muid is still remembered.
    public func isFinished(_ uid: String?) -> Bool {
        guard let uid = uid, !uid.isEmpty else { return false }
        lock.lock()
        defer { lock.unlock() }
        prune()
        return entries.contains { $0.uid == uid }
    }

    /// Forgets everything. Used when the user logs out and the next session should start clean.
    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }

    /// Caller holds `lock`.
    private func prune() {
        let cutoff = now().addingTimeInterval(-entryLifetime)
        entries.removeAll { $0.finishedAt <= cutoff }
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }
}
