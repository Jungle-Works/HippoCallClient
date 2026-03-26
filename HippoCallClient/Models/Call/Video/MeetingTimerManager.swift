//
//  MeetingTimerManager.swift
//  Pods
//
//  Created by Neha on 26/03/26.
//

import UIKit
import Foundation

final class MeetingTimerManager {

    static let shared = MeetingTimerManager()
    private var workItem: DispatchWorkItem?
    private var isRunning = false
    
    private init() {}

    // MARK: - Start Timer
    func start(duration: TimeInterval, onTimeout: @escaping () -> Void) {
        stop() // cancel any existing timer
        
        print("⏳ Timer started for \(duration) seconds")
        isRunning = true

        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.isRunning else { return }
            
            print("⏰ Timer fired - Auto ending meeting")
            DispatchQueue.main.async {
                onTimeout()
            }
        }
        
        workItem = item
        
        DispatchQueue.global().asyncAfter(deadline: .now() + duration, execute: item)
    }

    // MARK: - Stop Timer
    func stop() {
        if isRunning {
            print("🛑 Timer stopped manually")
        }
        
        isRunning = false
        workItem?.cancel()
        workItem = nil
    }
}
