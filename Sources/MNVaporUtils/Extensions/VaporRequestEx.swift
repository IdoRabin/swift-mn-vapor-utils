//
//  VaporRequestEx.swift
//  
//
// Created by Ido Rabin for Bricks on 17/1/2024.

public enum RedirectEncoding : Int {
    case base64
    case protobuf
    case normal
}

import Foundation
import Vapor
import Logging
import MNUtils

fileprivate let dlog : Logger? = Logger(label: "VaporRequestEx")


public extension Vapor.Request /* App-specific components */ {
    // TODO: Update paramKeysToNeverRedirect on init from Some app settings / hard-coded
    static var paramKeysToNeverRedirect : [String] = []
    static var appHasSessionMiddleware : Bool = true
    
    var domain : String? {
        guard let host = url.host else {
            return self.application.http.server.configuration.hostname
        }
        
        return MNDomains.sanitizeDomain(host)
    }
    
    var refererURL : URL? {
        if self.headers[.referer].count > 0, let url = URL(string: self.headers[.referer].first!) {
            // Was redirected / referer
            return url
        }
        return nil
    }
    
    var refererRoute : Route? {
        guard let refererURL = refererURL else {
            return nil
        }
        return application.routes.all.first { route in
            return route.mnRouteInfo?.canonicalRoute?.matches(url:refererURL, method: self.method) ?? false
        }
    }
    
    // MARK: Saving info to session store
    func saveToSessionStore<Key:ReqStorageKey>(key:Key.Type, value:(any JSONSerializable)?) {
        guard Self.appHasSessionMiddleware else {
            return
        }
        
        guard self.hasSession else {
            return
        }
        guard "\(type(of: value))" != "\(Key.Value.self)" else {
            dlog?.warning("saveToSessionStore will not encode:\(value.descOrNil) expected type: \(Key.Value.self)")
            return
        }
        
        // Will also save nil (and remove that key)
        if let value = value {
            if let infoStr = value.serializeToJsonString(prettyPrint: false) {
                self.session.data[key.asString] = infoStr
            } else {
                dlog?.warning("saveToSessionStore failed encoding \(key.asString) : \(type(of: value)) using serializeToJsonString()..")
            }
        } else {
            self.session.data[key.asString] = nil
        }
    }
    
    func getFromSessionStore<Value:JSONSerializable>(key:any ReqStorageKey.Type, required:Bool = false)->Value? {
        guard Self.appHasSessionMiddleware else {
            return nil
        }
        
        if let infoStr = self.session.data[key.asString] {
            if let val : Value = Value.deserializeFromJsonString(string: infoStr) {
                return val
            } else {
                dlog?.warning("getFromSessionStore failed decoding \(key.asString) : \(Value.self) using deserializeFromJsonString().. raw string: \(infoStr)")
            }
        } else if required {
            let msg =  "getFromSessionStore failed fetching \(key.asString) : \(Value.self) value was not found in self.session.data"
            dlog?.warning("\( msg )")
            preconditionFailure(msg)
        }
        return nil
    }
    
    func saveToSessionStore(userId:String?) {
        guard Self.appHasSessionMiddleware else {
            return
        }
        
        self.saveToSessionStore(key: ReqStorageKeys.selfUserID, value: userId)
    }

    // MARK: Saving info to request store
    func saveToReqStore<RSK:ReqStorageKey>(key:RSK.Type, value:RSK.Value?, alsoSaveToSession:Bool = false) {
        // Will also save nil (and remove that key)
        self.storage[key] = value
        
        if alsoSaveToSession && Self.appHasSessionMiddleware {
            if let value = value {
                if let val = value as? JSONSerializable {
                    self.saveToSessionStore(key: key, value: val)
                } else {
                    dlog?.note("saveToReqStore key [\(key.asString)] failed to save. \(type(of: value)) is not JSONSerializable. Value was = \(value)")
                }
            } else if alsoSaveToSession && Self.appHasSessionMiddleware{
                self.saveToSessionStore(key: key, value: nil)
            }
        }
    }

    // MARK: Fetching info from session and req. stroage
    /// Returns the stored current self user for this request -
    /// meaning, the request had an access token and the user associaced wth that token was saved in request storage as the self user.
    func getFromReqStore<Value:JSONSerializable>(key:any ReqStorageKey.Type, getFromSessionIfNotFound:Bool = true)->Value? {
        if let anyInfo = self.storage.get(key) {
            if let info = anyInfo as? Value {
                return info
            } else {
                dlog?.note("getFromReqStore key [\(key.asString)] failed to cast as? \(Value.self). Value was: \(type(of: anyInfo)) = \(anyInfo)")
            }
        }
        
        if getFromSessionIfNotFound && Self.appHasSessionMiddleware {
            if let infoStr = self.session.data[key.asString] {
                return Value.deserializeFromJsonString(string: infoStr)
            }
        }
        
        return nil
    }

}

public extension Vapor.Request /* convenience methods and more info  */ {
    
    static let REQUEST_UUID_STRING_PREFIX = "REQ|"
    static let URL_ESCAPE_ENCODED_DETECTION_CHARACTERSET = CharacterSet(charactersIn: "%+&=")
    
    static func requestUUIDString(id:String)->String {
        return id.adddingPrefixIfNotAlready(Vapor.Request.REQUEST_UUID_STRING_PREFIX)
    }
    
    /// Returns the request's ID: each request gets its own uuid for logging purposes.
    /// Example: "2D1ED539-CACF-4DB1-A6E6-2F8343135B3F"
    var requestUUIDString: String {
        get {
            let result : Logger.MetadataValue? = self.logger[metadataKey: "request-id"]
            if let result = result {
                switch result {
                case .string(let str):
                    return Self.requestUUIDString(id: str) // UUID as a string
                default:
                    let msg = "Vapor.Request.requestUUIDString element was of an unexpected type."
                    preconditionFailure(msg)
                }
            }
            let msg = "Vapor.Request.requestUUIDString was undefined"
            preconditionFailure(msg)
        }
    }
}
