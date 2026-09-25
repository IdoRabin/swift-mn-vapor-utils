//
//  MNRoutingHistoryItem.swift
//
//
//  Created by Ido on 06/02/2024.
//

import Foundation
import Vapor
import Logging
import MNUtils

fileprivate let dlog : Logger? = Logger(label: "RoutingHistoryItem")
fileprivate let dlogVerbose : Logger? = nil // Logger(label: "RoutingHistoryItemVe")

public class MNRoutingHistoryItem : JSONSerializable, Hashable, CustomStringConvertible {
    
    public struct Redirection : JSONSerializable, Hashable, Equatable, CustomStringConvertible {
        public let status : HTTPStatus
        public let url:URL
        public let reqId:String
        
        public init(url: URL, reqId: String, status: HTTPStatus = .temporaryRedirect) {
            self.status = status
            self.url = url
            self.reqId = reqId
        }
        
        public var shortDescription : String {
            return "\(url.absoluteString) reqId: \(reqId)"
        }
        
        // MARK: CustomStringConvertible
        public var description: String {
            return "<\(Self.self) " + self.shortDescription +  " status:\(status)>"
        }
    }
    
    public enum Action : JSONSerializable, Hashable, CustomStringConvertible {
        case none
        case error(MNErrorStruct)
        case redirectedFrom(Redirection)
        case redirectedTo(Redirection)
        
        var errorStruct : MNErrorStruct? {
            switch self {
            case .error(let err):
                return err
            default:
                return nil
            }
        }
        
        var redirectedFrom : Redirection? {
            switch self {
            case .redirectedFrom(let redirection):
                return redirection
            default:
                return nil
            }
        }
        
        var redirectedTo : Redirection? {
            switch self {
            case .redirectedTo(let redirection):
                return redirection
            default:
                return nil
            }
        }
        
        public var description: String {
            switch self {
            case .none:
                return ".none"
            case .error(let mnErrorStruct):
                return ".error(\(mnErrorStruct.error_code ?? 0) \(mnErrorStruct.error_reason)..)"
            case .redirectedFrom(let redirection):
                return ".redirectedFrom(\(redirection.shortDescription))"
            case .redirectedTo(let redirection):
                return ".redirectedTo(\(redirection.shortDescription))"
            }
        }
    }
    
    // MARK: Types
    // MARK: Const
    // MARK: Static
    // MARK: Properties / members
    public let requestId : String // not neccesarity a UUID! (expecting Vapor.Request.requestUUIDString(id: reqId))
    public let url : URL
    public let route : MNCanonicalRoute
    
    // Events / updated values
    private(set) public var lastStatus : HTTPResponseStatus
    private(set) public var lastErrorStruct :MNErrorStruct?
    private(set) public var lastRedirectedTo : Redirection?
    private(set) public var lastRedirectedFrom : Redirection?
    private(set) public var lastUpdate : Date
    
    // MARK: Private
    // MARK: Lifecycle
    // MARK: Public
    
    // MARK: CustomStringConvertible
    public var shortdescription: String {
        var strings : [String] = [
            "reqId: \(requestId)",
            "\(route.method) \(route.urlStr.asNormalizedPathOnly())",
            "[\(url.relativePath)]",
            "status: \(lastStatus.reasonPhrase)"
        ]
        if let lastErrorStruct = lastErrorStruct {
            strings.append("ERR: \(lastErrorStruct.error_code.descOrNil) \(lastErrorStruct.error_reason)")
        }
        if let lastRedirectedTo = lastRedirectedTo {
            strings.append("redirTo: \(lastRedirectedTo.shortDescription)")
        }
        if let lastRedirectedFrom = lastRedirectedFrom {
            strings.append("redirFrom: \(lastRedirectedFrom.shortDescription)")
        }
        
        return strings.joined(separator: " ")
        
    }
    public var description: String {
        return "<MNRoutingHistoryItem: \(self.shortdescription)>"
    }
    
    // MARK: Hashable
    public func hash(into hasher: inout Hasher) {
        // NOTE: Hash only non-state elements
        hasher.combine(requestId)
        hasher.combine(route)
    }
    
    public func stateHash(into hasher: inout Hasher) {
        hasher.combine(requestId)
        hasher.combine(route)
        hasher.combine(lastStatus)
        hasher.combine(lastErrorStruct)
        hasher.combine(lastRedirectedTo)
        hasher.combine(lastRedirectedFrom)
        hasher.combine(lastUpdate)
    }
    
    var stateHashInt : Int {
        var hasher = Hasher()
        self.stateHash(into:&hasher)
        return hasher.finalize()
    }
    
    // MARK: Equatable
    public static func ==(lhs:MNRoutingHistoryItem, rhs:MNRoutingHistoryItem)->Bool {
        return lhs.hashValue == rhs.hashValue
    }
    
    private func validate() throws {
        
        // Error vs. HttpStatus
        if let errorStruct = self.lastErrorStruct, let errStatus = errorStruct.error_http_status {
            if (errStatus.isCustom && self.lastStatus != .internalServerError) ||
                (errStatus.code != self.lastStatus.code) {
                let msg = "MNRoutingHistoryItem validate Error vs. HttpStatus failed: \(self.lastStatus) error: \(errorStruct.error_reason) errorStatus: \(errStatus)"
                // dlog?.warning("\(msg)")
                throw MNError(code:.http_stt_internalServerError, reason: msg, 
                              underlyingError:
                                MNError(code: .misc_failed_validation, reason: msg))
            }
        }
        
        // Redirection
        if lastRedirectedTo != nil && lastRedirectedFrom != nil {
            let msg = "MNRoutingHistoryItem validate redirection: redirectedTo AND redirectedFrom are BOTH defined!".mnDebug(add: "\(lastRedirectedTo!.description) vs. \(lastRedirectedFrom!.description)")
            // dlog?.warning("\(msg)")
            throw MNError(code:.http_stt_internalServerError, reason: msg,
                          underlyingError:
                            MNError(code: .misc_failed_validation, reason: msg))
            
        }
    }
                
    // NOTE: Returns true if was actually changed
    internal init(req:Request, response:Response? = nil, action:Action? = nil) throws {
        self.requestId = req.requestUUIDString // Uses under the hood: Vapor.Request.requestUUIDString(id: reqId)
        self.url = req.url.url
        self.route = req.route?.mnRouteInfo?.canonicalRoute ?? MNCanonicalRoute(urlStr: req.url.string, method: req.method)
        self.lastErrorStruct = action?.errorStruct
        self.lastUpdate = Date.now // init time
        
        // Set new Http status:
        var newStatus = response?.status ?? .ok
        if let newCode = action?.errorStruct?.error_http_status?.code {
            // Casting: error?.httpStatus may be MNUtils.HTTPResponseStatus
            newStatus = NIOHTTP1.HTTPResponseStatus(statusCode: Int(newCode))
        }
        self.lastStatus = newStatus
        try self.validate()
        
        // Redirect?
        self.lastRedirectedTo = action?.redirectedTo
        self.lastRedirectedFrom = action?.redirectedFrom
        if MNUtils.debug.IS_DEBUG {
            if let reditto = self.lastRedirectedTo {
                dlog?.info(">> set history lastRedirectedTo: \(reditto.shortDescription)")
            }
            if let reditFrom = self.lastRedirectedFrom {
                dlog?.info("?? set history lastRedirectedFrom: \(reditFrom.shortDescription)")
            }
        }
    }
    
    
    /// Update the MNRoutingHistoryItem with new info:
    /// - Parameters:
    ///   - req: request for this history item
    ///   - response: response for this history item
    ///   - error: possible error to update regarding this history item
    internal func update(req:Request, response:Response? = nil, action:Action = .none) throws -> Bool {
        let reqId = req.requestUUIDString
        let mnCRoute = req.route?.mnRouteInfo?.canonicalRoute ?? MNCanonicalRoute(urlStr: req.url.string, method: req.method)
        
        guard self.requestId == reqId else {
            throw MNError(code:.http_stt_notAcceptable, reason: "update routing".mnDebug(add: "MNRoutingHistoryItem.update(...) request id mismatch"))
        }
        
        guard self.route.matches(other:mnCRoute) else {
            throw MNError(code:.http_stt_notAcceptable, reason: "update routing".mnDebug(add: "MNRoutingHistoryItem.update(...) canonical route mismatch"))
        }
        
        // Follow changes:
        let before = stateHashInt
        var wasChanged = false
        var newErrorStruct : MNErrorStruct? = action.errorStruct
        var newStatus = self.lastStatus
        
        if let response = response {
            newErrorStruct = newErrorStruct ?? response.asMNErrorStruct
            dlogVerbose?.info("--- updated status: \(response.status)")
            newStatus = response.status
        }
        
        // Update Error
        if newErrorStruct != self.lastErrorStruct {
            let prevErrorStruct = self.lastErrorStruct
            self.lastErrorStruct = newErrorStruct
            if let prev = prevErrorStruct {
                self.lastErrorStruct?.update(underlyingErrorStructs: [prev])
            }
            dlogVerbose?.info("--- updated lastError: \(newErrorStruct.descOrNil)")
            wasChanged = true
        }
        
        // Set new Http status if error param was provided, so that the status matches the error:
        if let newCode = action.errorStruct?.error_http_status?.code {
            // Casting: error?.httpStatus may be MNUtils.HTTPResponseStatus
            newStatus = NIOHTTP1.HTTPResponseStatus(statusCode: Int(newCode))
            if newStatus.isCustom {
                newStatus = .internalServerError
                dlogVerbose?.info("--- updated newStatus to internalServerError because error code: \(action.errorStruct?.mnErrorCode()?.reason ?? "<??>" ) is not http status!")
            }
        }
        
        if self.lastStatus != newStatus {
            self.lastStatus = newStatus
            wasChanged = true
        }
        
        // Redirection:
        if let redirectedTo = action.redirectedTo, redirectedTo != self.lastRedirectedTo {
            dlogVerbose?.info("--- updated redirectedTo: \(redirectedTo)")
            self.lastRedirectedTo = redirectedTo
            wasChanged = true
        }
        
        
        if let redirectedFrom = action.redirectedFrom, redirectedFrom != self.lastRedirectedFrom {
            dlogVerbose?.info("--- updated redirectedFrom: \(redirectedFrom) referer: \(req.refererURL.descOrNil) \(req.refererRoute.descOrNil)")
            self.lastRedirectedFrom = redirectedFrom
            wasChanged = true
        }
        
        if wasChanged || self.stateHashInt != before {
            self.lastUpdate = Date.now // change time when an actual change occurs
            // dlog?.info("MNRoutingHistoryItem.updated: \(self.shortdescription)")
            try self.validate()
            wasChanged = true
        }
        
        return wasChanged
    }
}
