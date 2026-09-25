//
//  VaporRouteEx.swift
//
//
//  Created by Ido on 18/01/2024.
//

import Foundation
import MNUtils
import Vapor

// Assigns a "setting" to a route:
public extension Route {
    
    
    /// Add metadata into the Route.userInfo by key MN_ROUTE_INFO_KEY ("mnRouteInfo")
    /// - Parameter info: metadata info to add to the route
    /// - Returns: the route itslef in order to allow daisy chaining
    @discardableResult
    func /* set */metadata(_ info:MNRouteInfo)->Route {
        var info = info
        info.update(withRoute:self)
        self.userInfo[MN_ROUTE_INFO_KEY] = info
        return self
    }
    
    @discardableResult
    func setMNRouteGroup(_ group:MNRouteGroup)->Route {
        self.userInfo[MN_ROUTE_GROUP_KEY] = group
        return self
    }
    
    // Properties
    var mnRouteInfo : MNRouteInfo? {
        get {
            return self.userInfo[MN_ROUTE_INFO_KEY] as? MNRouteInfo
        }
    }
    
    var mnRouteGroup : MNRouteGroup? {
        get {
            return self.userInfo[MN_ROUTE_GROUP_KEY] as? MNRouteGroup
        }
    }
}
