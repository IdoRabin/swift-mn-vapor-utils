//
//  File.swift
//  
//
// Created by Ido Rabin for Bricks on 17/1/2024.

import Foundation
import MNUtils
import LeafKit
import Logging

fileprivate let dlog: Logger? = Logger(label: "LexerErrorEx")

public extension LexerError {
    func asDict()->StringStringDictionary {
        var reasonStr = "Unknow"
        switch self.reason {
        case .invalidParameterToken(let str):
            reasonStr = "Invalid parameter token: \(str)"
        case .unterminatedStringLiteral:
            reasonStr = "Unterminated string literal"
        case .unknownError(let str):
            reasonStr = "Unknown error: \(str)"
        }
        let nsError = self as NSError
        return [
            "name" : "Leaf LEXER error",
            "code" : "\(nsError.code)",
            "loc_name":name,
            "loc_line":String(line),
            "loc_col":String(column),
            "reason":reasonStr,
        ]
    }
}

extension LexerError : @retroactive JSONSerializable {
    
    // MARK: Coding keys
    enum CodingKeys : String, CodingKey, CaseIterable {
        case errName = "err_name"
        case errCode = "err_code"
        case errReason = "err_reason"
        case locName = "loc_name"
        case locLine = "loc_line"
        case locCol = "loc_column"
        
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var reasonStr = "Unknow"
        switch self.reason {
        case .invalidParameterToken(let char):
            reasonStr = "Invalid parameter token: \(char)"
        case .unterminatedStringLiteral:
            reasonStr = "Unterminated string literal"
        case .unknownError(let str):
            reasonStr = "Unknown error: \(str)"
        }
        let nsError = self as NSError
        
        try container.encode(reasonStr, forKey: .errReason)
        try container.encode(nsError.code, forKey: .errCode)
        try container.encode("Leaf LEXER error", forKey: .errName)
        
        try container.encode(line, forKey: .locName)
        try container.encode(column, forKey: .locLine)
        try container.encode(name, forKey: .locCol)
    }
    
    public init(from decoder: Decoder) throws {
        dlog?.warning("Lexer error cannot be decoded!")
        preconditionFailure("Lexer error cannot be decoded!")
//        var container = try decoder.container(keyedBy: CodingKeys.self)
//        let reasonStr = try container.decode(String.self, forKey: .errReason)
//        var areason : Reason = .unknownError("Unknown err (decode error)")
//        switch reasonStr.substring(untilFirstOccuranceOf: " ") {
//        case "Invalid":         areason = .invalidParameterToken(reasonStr.last ?? "?")
//        case "Unterminated":    areason = .unterminatedStringLiteral
//        case "Unknown":
//            fallthrough
//        default:
//            areason = .unknownError(reasonStr.trimmingPrefix("Unknown error: "))
//        }
//        
//        
//        // (self as NSError).code = container.decode(Int.self, forKey: .errCode)
//        reason = areason
//        line = try container.decode(Int.self, forKey: .locLine)
//        column = try container.decode(Int.self, forKey: .locCol)
    }
    
    
}
