//
//  VaporRoutingKitPathComponentEx.swift
//
//
//  Created by Ido on 18/01/2024.
//

import Foundation
import RoutingKit

// extending Vapor RoutingKit PathComponent
extension RoutingKit.PathComponent /* from array of strings */ {
    
    /* Redundant conformance:
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        self.init(stringLiteral: string)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }*/
    
    /// Create an array of path components using a given array of strings
    /// - Parameter strings: array of strings, will ignore strings sized 0 or larger than 1024 chars
    /// - Returns: an array of all valid path components created in the same orded as the input string array
    public static func arrays(fromPathStrings strings:[String])->[[PathComponent]] {
        let result : [[PathComponent]] = strings.compactMap { str in
            if str.count > 0 && str.count < 1024 {
                return str.pathComponents
            }
            return nil
        }
        return result
    }
}

public extension Sequence where Element == RoutingKit.PathComponent {
    var fullPath:String {
        return "/" + self.descriptions().joined(separator: "/")
    }
    
    var strings : [String] {
        return self.map { $0.description }
    }
}

public extension Array where Element == RoutingKit.PathComponent {
    var fullPath:String {
        return self.map { elem in
            "\(elem)"
        }.joined(separator: "/").asNormalizedPathOnly()
        
        // We hate $0 notation!
        // return self.map { "\($0)" }.joined(separator: "/")
    }
    
    
    /// returns a new array of path components, with an additional last path component created using the given string
    /// - Parameter strComp: string for the new PathComponent to append
    /// - Returns: a new array with an additional PathComponent pointing at the given (strComp) string
    func appending(strComp:String)->[RoutingKit.PathComponent] {
        let newComp = RoutingKit.PathComponent(stringLiteral: strComp)
        return self.appending(newComp)
    }
    
    var strings : [String] {
        return self.map { $0.description }
    }
}

public extension RoutingKit.PathComponent {
    /// returns a new array of path components, with an additional last path component created using the given string
    /// - Parameter strComp: string for the new PathComponent to append
    /// - Returns: a new array with an additional PathComponent pointing at the given (strComp) string
    func appending(strComp:String)->[RoutingKit.PathComponent] {
        let newComp = RoutingKit.PathComponent(stringLiteral: strComp)
        return [self].appending(newComp)
    }
}
