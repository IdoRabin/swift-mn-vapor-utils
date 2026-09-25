//
//  MNCanonicalRoute.swift
//
//
//  Created by Ido on 04/02/2024.
//

import Foundation
import MNUtils
import Vapor
import NIO
import NIOHTTP1
import Logging

fileprivate let dlog : Logger? = Logger(label:"MNCanonicalRoute")

public struct MNCanonicalRoute : Sendable, JSONSerializable, Hashable, CustomStringConvertible {
    public let urlStr: String
    public let method: HTTPMethod
    
    // MARK: CustomStringConvertible
    public var description: String {
        return "\(method) \(urlStr.asNormalizedPathOnly())"
    }
    
    private func matchMethods(method methodToTest:HTTPMethod? = nil)->Bool {
        guard let methodToTest = methodToTest else {
            return true
        }
        
        return (methodToTest == self.method)
    }
    
    public func matches(url urlToTest:URL?, method methodToTest:HTTPMethod? = nil)->Bool {
        guard let urlToTest = urlToTest else {
            return false
        }
        
        guard (urlToTest.relativePath.asNormalizedPathOnly() == self.urlStr.asNormalizedPathOnly()) else {
            return false
        }
        
        guard self.matchMethods(method: methodToTest) else {
            return false
        }
        
        // Match did not fail:
        return true
    }
    
    public func matches(other:MNCanonicalRoute?)->Bool {
        guard let other = other else {
            return false
        }
        guard let url = URL(string: other.urlStr) else {
            let msg = "MNCanonicalRoute.matches(other) failed to create URL".mnDebug(add: " string:\(other.urlStr)")
            dlog?.warning("\(msg)")
            return false
        }
        return self.matches(url: url, method: other.method)
    }
}
