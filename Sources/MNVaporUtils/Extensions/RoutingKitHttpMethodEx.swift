//
//  RoutingKitHttpMethodEx.swift
//
//
//  Created by Ido on 24/01/2024.
//

import Foundation
#if canImport(NIO)
import NIO
import NIOHTTP1

extension NIOHTTP1.HTTPMethod : @retroactive Hashable {
    // MARK: Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.rawValue)
    }
}

extension NIOHTTP1.HTTPMethod : Codable {
    // Does not require implementation becuase its also RawRepresentable (String)
}
#endif
