//
//  VaportRouteCollectionEx.swift
//
//
// Created by Ido Rabin for Bricks on 17/1/2024.

import Foundation
import Vapor

// Extension
public extension RouteCollection /* extension */ {
    
    // name allows to use in conincidence with the "tag" in OpenAPI to collate routes to groups
    var name : String {
        return "\(Self.self)".replacingOccurrences(ofFromTo: [
            "Controller":"",
            "Vapor":""
        ], caseSensitive: false).trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }
    
}
