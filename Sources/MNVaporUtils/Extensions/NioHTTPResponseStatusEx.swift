//
//  NioHTTPResponseStatusEx.swift
//  NIO HTTPResponseStatus extension
//
// Created by Ido Rabin for Bricks on 17/1/2024.

import Foundation
import Vapor

// Extends SwiftNio HTTPResponseStatus with custom status codes.
public extension HTTPResponseStatus {
    
    // We have a mapping of real http status codes to our own - this allows changing the mapped statuses later:
    
    /// Input was syntactically correct, but not semantically (usually failed validations).
    static var invalidInput : HTTPResponseStatus = HTTPResponseStatus.notAcceptable // 406 not acceptable
    
    
    /// requested data not found, while the request URI exists and is valid, and input data is valid and yielded an empty collection of object/s
    static var dataNotFound : HTTPResponseStatus = HTTPResponseStatus.noContent // 204 No content
    
    var isCustom : Bool {
        get {
            switch self {
            case .custom(_, _):
                return true
            default:
                return false
            }
        }
    }
    
    var isRedirect : Bool {
        return (300...399).contains(self.code)
    }
}

public extension Sequence where Element == HTTPResponseStatus {
    var codes : [Int] {
        return self.map { Int($0.code) }
    }
}

public extension Array where Element == HTTPResponseStatus {
    var codes : [Int] {
        return self.map { Int($0.code) }
    }
}

