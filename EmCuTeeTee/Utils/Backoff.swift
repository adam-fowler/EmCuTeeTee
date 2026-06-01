//
//  Backoff.swift
//  EmCuteetee
//
//  Created by Adam Fowler on 01/06/2026.
//

struct Backoff {
    var wait: Double
    
    init() {
        self.wait = 0.05
    }
    
    mutating func reset() {
        self.wait = 0.05
    }
    
    mutating func wait() async throws {
        try await Task.sleep(for: .seconds(wait))
        wait *= 2.0
        wait *= Double.random(in: 0.75..<1.25)
        wait = min(wait, 30.0)
    }
}
