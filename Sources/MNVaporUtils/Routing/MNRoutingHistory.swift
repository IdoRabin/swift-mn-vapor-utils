//
//  MNRoutingHistory.swift
//
//
//  Created by Ido on 20/11/2022.
//

import Foundation
import Vapor
import Logging
import MNUtils

fileprivate let dlog : Logger? = Logger(label: "RoutingHistory")
fileprivate let dlogVerbose : Logger? = nil // Logger(label: "RoutingHistoryVe")

// NOTE: VAPOR defines a public typealias HTTPStatus = NIOHTTP1.HTTPResponseStatus

extension Redirect {
    static let all : [Redirect] = [.normal, .permanent, .temporary]
    static let allHttpStatuses : [NIOHTTP1.HTTPResponseStatus] = [Redirect.normal.status, Redirect.permanent.status, Redirect.temporary.status]
}

internal struct MNRoutingHistoryStorageKey : ReqStorageKey {
    typealias Value = MNRoutingHistory
}

// This class should NOT save
public class MNRoutingHistory : JSONSerializable, Hashable, CustomStringConvertible {
    
    public static let DEFAULT_MAX_ITEMS = 15 // Maximum history items per session
    public static let SAVES_FILE_REQUESTS = false
    
    // MARK: static
    static let UNKNOWN_REQ_ID = "UNKNOWN_REQ_ID"
    
    // MARK: members
    var items : [MNRoutingHistoryItem] = []
    private var _maxItems : Int = DEFAULT_MAX_ITEMS
    // TODO: Convert to AppSettable or add to the AppSettings...
    // @AppSettable(name: "RoutingHistory.maxItems", default: RoutingHistory.DEFAULT_MAX_ITEMS) static var maxItems : Int
    
    var maxItems : Int {
        get {
            return _maxItems
        }
        set {
            if newValue >= 3 && newValue <= 16384 {
                _maxItems = newValue
            } else {
                dlog?.warning("MNRoutingHistory set maxItems must be between 3 and 16384")
            }
        }
    }
    
    // MARK: Getters / computed properties
    public var first : MNRoutingHistoryItem? {
        return items.first
    }
    
    public var last : MNRoutingHistoryItem? {
        return items.last
    }
    
    public var oneBeforeLast : MNRoutingHistoryItem? {
        guard items.count > 1 else {
            return nil
        }
        return items[items.count - 2]
    }
    
    // MARK: private
    func save(to req:Request) {
        req.saveToSessionStore(key: MNRoutingHistoryStorageKey.self, value: self)
    }
    
    public func findItem(otherItem : MNRoutingHistoryItem)->MNRoutingHistoryItem? {
        return items.reversed().first { item in
            item == otherItem
        }
    }
    
    public func findItem(req:Request)->MNRoutingHistoryItem? {
        return items.reversed().first { item in
            item.requestId == req.requestUUIDString
        }
    }
    
    public func findItem(reqId:String)->MNRoutingHistoryItem? {
        let reqId = Vapor.Request.requestUUIDString(id: reqId)
        return items.reversed().first(where: { item in
            item.requestId == reqId && item.lastErrorStruct != nil
        })
    }
        
    public func first(where block:(_ item:MNRoutingHistoryItem)->Bool)->MNRoutingHistoryItem? {
        return items.reversed().first { item in
            return block(item)
        }
    }
    
    public func getError(byReqId reqId: String)->MNErrorStruct? {
        let reqId = Vapor.Request.requestUUIDString(id: reqId)
        return items.reversed().first { item in
            item.requestId == reqId && item.lastErrorStruct != nil
        }?.lastErrorStruct
    }
    
    
    /// Returns the most recent history item that contains an error
    /// - Parameter limit: limits how many items back should we go. Default is 2 items back and no more.
    /// - Parameter timeBackCutoff: Cutoff in seconds to the past, items older than this amout are ignored. Default is a cutoff of 5 seconds into the past.
    /// - Returns: the first history item encountered that contains an error within the limitations
    public func getLatestErrorItem(limit:Int = 2, timeBackCutoff:TimeInterval = 5)->MNRoutingHistoryItem? {
        let index = 0
        for item in items.reversed() {
            if index >= limit {
                return nil
            } else if (item.lastErrorStruct != nil && 
                       abs(item.lastUpdate.timeIntervalSinceNow) < timeBackCutoff) {
                return item
            }
        }
        return nil
    }
    
    
    /// Deduces the redirectedFrom for a history item using a the history items, and the request. We ferch the referer from the request and the redirectTo from the prvious history item,
    /// rerturning a HistoryItem action of .redirectTo if we deduced successfully:
    /// - Parameters:
    ///   - item: history item to deduce  a redirectedFrom for.
    ///   - req: request of the history item being added (expected after the redirect, thus the req should have a referer header
    ///   - response: response, if available of the request
    /// - Returns:a redirectedFrom action for a history item, filled with the data of the (previous) history item thet initiated the redirect.
    private func deduceRedirectFrom(item:MNRoutingHistoryItem, for req:Request, response:Response? = nil) -> MNRoutingHistoryItem.Action? {
        let prfx = "    MNRoutingHistory.deduceRedirectFrom:"
        
        // if cur response is a redirect we are at the hisotry item that is BEING redirected TO, i.e we for sure do not need to return a redirectFrom.
        if response?.status.isRedirect ?? false {
            return nil
        }
        
        let prev = (self.last == item) ? self.oneBeforeLast : self.last
        let refererItem = self.first { item in
            item.requestId != item.requestId &&
            (200...299).contains(Int(item.lastStatus.code))
        }
        
        dlogVerbose?.info("\(prfx) \(prev?.requestId ?? "<no prev>") redirTo: \(prev?.lastRedirectedTo?.shortDescription ?? "<no redirTo>")")
        if let prev = prev {
            var isAllowed = true
            
            if let refererURL = req.refererURL, let refererItem = refererItem {
                // NOTE: Referer URL should equal the last valid (.ok status or similar) URL the client has visited!
                if refererItem.url.relativePath == refererURL.relativePath {
                    dlogVerbose?.success("\(prfx) referer url validated!")
                } else {
                    let msg = "\(prfx) referer url differs from refererItem".mnDebug(add: "\(refererItem.url.relativePath) != \(refererURL.relativePath)")
                    dlog?.warning("\(msg)")
                    isAllowed = false
                }
            } else {
                // No referer url in cur req
            }
            
            if let redirTo = prev.lastRedirectedTo {
                if req.url.url.relativePath == redirTo.url.relativePath {
                    dlogVerbose?.success("\(prfx) cur url matches prev redirect to!")
                } else {
                    let msg = "\(prfx) cur url differs from redirectTo".mnDebug(add: "\(req.url.url.relativePath) != \(redirTo.url.relativePath)")
                    dlog?.warning("\(msg)")
                    isAllowed = false
                }
            } else {
                // No redirTo in history's prev item! (this means "this" / current item/req should NOTE get a redirFrom)
                isAllowed = false
            }
            
            if let paramPrevReqId = req.parameters.get("req_id") {
                if prev.requestId == paramPrevReqId {
                    dlogVerbose?.success("\(prfx) param req_id matches prev item request id!")
                } else {
                    let msg = "\(prfx) param req_id differs from prev request id".mnDebug(add: "\(paramPrevReqId) != \(prev.requestId)")
                    dlog?.warning("\(msg)")
                    isAllowed = false
                }
            }
            
            if isAllowed {
                return MNRoutingHistoryItem.Action.redirectedFrom(MNRoutingHistoryItem.Redirection(url: prev.url,
                                                                                                   reqId: prev.requestId,
                                                                                                   status: prev.lastStatus))
            }
        }
        
        return nil
    }
                
    @discardableResult
    public func update(req:Request, response:Response? = nil, action: MNRoutingHistoryItem.Action = .none) throws ->MNRoutingHistoryItem? {
        
        // We should not save file-requests, such as .js, .svg, .jpg, .ico files etc.
        let isFileRequest = req.url.url.pathExtension.count > 0
        if isFileRequest && !Self.SAVES_FILE_REQUESTS {
            return nil
        }
        
        var result : MNRoutingHistoryItem? = nil
        if let aresult = self.findItem(req: req) {
            result = aresult
            let res = try result?.update(req: req, response: response, action: action)
            dlogVerbose?.info("   Found history item \(result!.requestId) out of \(self.items.count) items. Result: \(res.descOrNil)")
        } else {
            result = try MNRoutingHistoryItem(req: req, response: response, action: action)
            
            self.items.append(result!)
            dlogVerbose?.info("   Created new history item \(result!.requestId) \(result!.route.description) (\(self.items.count) items)")
            
            // Update with deduced redirectFrom, if provided, and previous item was a redirectTo + referer etc:
            // We ferch the referer from the request and the redirectTo from the prvious history item, and deduce the redirectedFrom:
            if let redirectFrom = self.deduceRedirectFrom(item:result!, for: req, response: response) {
                let res = try result?.update(req: req, response: response, action: redirectFrom)
                dlogVerbose?.info("   Found history item (REDIRECTED) \(result!.requestId) out of \(self.items.count) items. Result: \(res.descOrNil)")
            }
        }
        guard let result = result else {
            throw MNError(code:.misc_failed_creating, reason: "Failed creating routing history item".mnDebug(add: "Req: \(req.description)"))
        }
        
        self.save(to: req)
        
        return result
    }
        
    // MARK: Equatable
    public static func == (lhs: MNRoutingHistory, rhs: MNRoutingHistory) -> Bool {
        return lhs.items == rhs.items
    }
    
    // MARK: Hahsable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(items)
    }
    
    // MARK: CustomStringConvertible
    public var description: String {
        return items.descriptionLines
    }
    
    public func debugDescLines()->[String] {
        var result : [String] = ["RouteHistory \(items.count) items"]
        
        self.items.forEachIndex { index, item in
            let line = "\(String(index).paddingLeft(toLength: 2, withPad: " ")). HItem: \(item.shortdescription)"
            result.append(line)
        }
        return result
    }
}

public extension Vapor.Request /* MNRoutingHistory / routing history */ {
    
    
    /// Route history for the session, accessible from the requst. Max recent history items can be specified and changed.
    /// NOTE: Requires vapor config of: app.middleware.use(app.sessions.middleware)
    var routeHistory : MNRoutingHistory? {
        return self.routeHistory(maxItems: MNRoutingHistory.DEFAULT_MAX_ITEMS)
    }
    
    /// Route history for the session, accessible from the requst. Max recent history items can be specified and changed.
    /// NOTE: Requires vapor config of: app.middleware.use(app.sessions.middleware)
    func routeHistory(maxItems newMaxItems:Int)->MNRoutingHistory? {
        guard self.hasSession else {
            let msg = "MNRoutingHistory / MNSessionHistoryMiddleware requires activating Vapor sessions:\n app.middleware.use(app.sessions.middleware) -"
            dlog?.note("\(msg)")
            // preconditionFailure()
            return nil
        }
        
        var result : MNRoutingHistory? = self.getFromSessionStore(key: MNRoutingHistoryStorageKey.self)
        
        //  if doesn't exist we Create and save the new history (session):
        if result == nil {
            result = MNRoutingHistory()
            self.saveToSessionStore(key: MNRoutingHistoryStorageKey.self, value: result)
            dlogVerbose?.info(" Created new route history. sessioniD: \(self.session.id.wrappedValue.descOrNil)")
        } else {
            // dlogVerbose?.info(" Found an existing route history. \(result?.items.count.description ?? "?") items. sessioniD: \(self.session.id.wrappedValue.descOrNil)")
        }
        
        // We assume result was found or created!
        guard let result = result else {
            let msg = "MNRoutingHistory init / get failed for session id: \(self.session.id.descOrNil)"
            dlog?.note("\(msg)")
            return nil
        }
        
        if result.maxItems != newMaxItems {
            result.maxItems = newMaxItems
        }
        return result
    }
}
