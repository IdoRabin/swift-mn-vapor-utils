//
//  FluentMigrationsEx.swift
//
//
// Created by Ido Rabin for Bricks on 17/1/2024.

import Foundation
import Fluent

fileprivate let dlog: Logger? = Logger(label: "FluentMigrationEx")

public extension Migration {
    var shortName : String {
        let result = self.name.replacingOccurrences(ofFromTo:[
            "App" : "",
            "MN" : "",
            "com." : "",
            ".com" : "",
        ])
        dlog?.todo("Implement shortName for Migration: [\(result)]")
        return result
    }
}

public extension Sequence where Element : Migration {
    var shortNames : [String] {
        return self.map { $0.shortName }
    }
}

public extension Array where Element : Migration {
    var shortNames : [String] {
        return self.map { $0.shortName }
    }
}

