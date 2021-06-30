//
//  UserDefaultProperties.swift
//  EmCuTeeTee
//
//  Created by Adam Fowler on 18/07/2020.
//  Copyright © 2020 Adam Fowler. All rights reserved.
//

import Foundation

/// UserDefault property wrapper
@propertyWrapper
public struct UserDefault<Value> {
    public var value: Value
    public let key: String

    init(wrappedValue: Value, key: String) {
        self.value = UserDefaults.standard.object(forKey: key) as? Value ?? wrappedValue
        self.key = key
    }

    public var wrappedValue: Value {
        get {
            return self.value
        }
        set {
            self.value = newValue
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

@propertyWrapper
public struct UserDefaultCodable<Value: Codable> {
    public var value: Value
    public let key: String

    init(wrappedValue: Value, key: String) {
        if let data = UserDefaults.standard.data(forKey: key),
            let value = try? JSONDecoder().decode(Value.self, from: data) {
            self.value = value
        } else {
            self.value = wrappedValue
        }
        self.key = key
    }

    func save() {
        if let data = try? JSONEncoder().encode(self.value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    public var wrappedValue: Value {
        get {
            return self.value
        }
        set {
            self.value = newValue
            save()
        }
    }
}

