//
//  FluentPSQLErrorEx.swift
//
//
// Created by Ido Rabin for Bricks on 17/1/2024.

import FluentPostgresDriver

public extension PSQLError {

    /// PSQLError full description including the backing info.
    var fullDescription : String {
        var arr = [
            "<PSQLError",
            "code \(self.code)",
            "file: \(self.file.descOrNil)",
            "ln# \(self.line.descOrNil)",
            "query: \(self.query.descOrNil)",
            "serverInfo: \(self.serverInfo.descOrNil)",
            " >"
        ]
        arr.append("")
        return arr.joined(separator: " ")
    }
}
