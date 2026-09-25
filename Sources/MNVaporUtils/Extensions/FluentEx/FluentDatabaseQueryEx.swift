//
//  FluentDatabaseQueryEx.swift
//
//
// Created by Ido Rabin for Bricks on 17/1/2024.

import Foundation
import Fluent

public extension Fluent.DatabaseQuery.Filter.Method {
    static var caseInsensitve : Self {
        return .custom("ilike")
    }
}
