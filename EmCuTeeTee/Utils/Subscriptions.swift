//
//  Subscriptions.swift
//  EmCuteetee
//
//  Created by Adam Fowler on 28/05/2026.
//
import Synchronization

/// Thread safe management of subscriptions
final class Subscriptions: Sendable {
    let subscriptions: Mutex<[String: AsyncStream<Void>.Continuation]>
    
    init() {
        self.subscriptions = .init([:])
    }
    
    func addNewSubscription(_ topic: String, cancelContinuation: AsyncStream<Void>.Continuation) -> Bool {
        subscriptions.withLock {
            guard $0[topic] == nil else { return false}
            $0[topic] = cancelContinuation
            return true
        }
    }
    
    func cancelSubscription(_ topic: String) {
        subscriptions.withLock {
            guard let continuation = $0[topic] else { return }
            continuation.yield()
            $0.removeValue(forKey: topic)
        }
    }
}

