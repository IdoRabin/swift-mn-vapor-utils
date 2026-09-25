//
//  MNRouteGroup.swift
//
//
//  Created by Ido on 03/02/2024.
//

import Foundation
import Vapor
import MNUtils

import Logging
 
fileprivate let dlog: Logger? = Logger(label: "MNRouteGroup")

let MN_ROUTE_GROUP_KEY = "mnRouteGroup"

// NOTE: We are using a class because a single MNRouteGroup is shared between multiple routes, so we want to make sure
//

public class MNRouteGroup : @unchecked Sendable, JSONSerializable, CustomDebugStringConvertible, Hashable {
    
    // MARK: Types
    public typealias ProductType = MNRouteInfo.ProductType
    public typealias MNRouteGroupTag = String
    
    // MARK: Const
    static let PATH_COMPS_TO_IGNORE = ["api", "v1", "v2", "v3", "v4"]
    
    static let PATH_COMPS_FOR_TYPE  = [["api", "v1", "v2", "v3", "v4"]:ProductType.apiResponse,
                                       ["images", "css", "scripts", "web_scripts"]:ProductType.file]
    
    private(set) public static var groups : [MNRouteGroupTag:MNRouteGroup] = [:]
    
    // MARK: Static
    
    // MARK: Properties / members
    // Hashed
    public let groupTag: MNRouteGroupTag
    public let productType: ProductType
    public var canonicalRoutes: [MNCanonicalRoute]
    
    // Non-Hashed
    public let title: String?
    public let description: String?
    
    // MARK: Lifecycle
    // MARK: Public
    // MARK: Private
    public init(groupTag: String, productType: ProductType, title: String?, description: String?) {
        self.groupTag = groupTag
        self.productType = productType
        self.title = title
        self.description = description
        self.canonicalRoutes = []
    }
    
    fileprivate static func deduceMNRouteGroupsFromRoutes(app:Application)->[MNRouteGroupTag:MNRouteGroup] {
        var productTypes : [MNRouteGroupTag:[ProductType]] = [:]
        var routesByTag : [MNRouteGroupTag:[Route]] = [:]
        var result : [MNRouteGroupTag:MNRouteGroup] = [:]
        
        for route in app.routes.all {
            if let info = route.mnRouteInfo {
                productTypes[info.groupTag] = (productTypes[info.groupTag] ?? []).appending(info.productType)
                routesByTag[info.groupTag] = (routesByTag[info.groupTag] ?? []).appending(route)
                if let group = route.mnRouteGroup {
                    result[info.groupTag] = group
                }
            }
        }
        
        let typesByTag : [MNRouteGroupTag:ProductType] = productTypes.mapValues { typesArr in
            return typesArr.majorityValue(whenTwoVals: .first) ?? .apiResponse
        }
        // dlog?.info("MNRouteGroup discovered majorityTypes: \(typesByTag.descriptionLines)")
        
        for (atag, _ /*aroutes*/) in routesByTag {
            if result[atag] == nil {
                let productType = typesByTag[atag] ?? .apiResponse
                let baseTitle = atag.capitalized
                let group = MNRouteGroup(groupTag: atag,
                                         productType: productType,
                                         title: "\(baseTitle) group",
                                         description: "\(baseTitle) group of routes. Returns results mainly of type: \(productType.rawValue).")
                result[atag] = group
            }
        }
        
        // dlog?.info("MNRouteGroup merged all groups: \(result.descriptionLines)")
        
        return result
    }
    
    
    /// Iterates all routes in the application and deduces MNRouteGroups, assigns them to the routes
    /// - Parameter app: application to iterate over all its registered routes
    /// - Returns: all created route groups keyed by their tag
    @discardableResult
    public static func deduceAllMNRouteGroups(app:Application)->[MNRouteGroupTag:MNRouteGroup] {
        
        // 1. First pass: count how many request types for each route,
        // Assign persumed type for all other types
        let newGroups : [MNRouteGroupTag:MNRouteGroup] = self.deduceMNRouteGroupsFromRoutes(app: app)
        
        // Assign new RouteGroups to the routes:
        for route in app.routes.all {
            if let info = route.mnRouteInfo {
                if let newGroup = newGroups[info.groupTag] {
                    if MNUtils.debug.IS_DEBUG, let existingGroup = route.mnRouteGroup, existingGroup != newGroup {
                        dlog?.note("MNRouteGroup replacing:")
                        dlog?.note("  EXISTING GROUP:\(existingGroup.serializeToJsonString(prettyPrint: true).descOrNil))")
                        
                        dlog?.note("       NEW GROUP:\(newGroup.serializeToJsonString(prettyPrint: true).descOrNil)")
                    }
                    route.setMNRouteGroup(newGroup)
                    if let canonRoute = info.canonicalRoute {
                        newGroup.canonicalRoutes.appendIfNotAlready(canonRoute)
                    }
                } else {
                    dlog?.note("MNRouteGroup route: [\(route.method) \(route.path.string)] has no new MNRouteGrou! Please update func deduceMNRouteGroupsFromRoutes or expicitly create an MNRouteGroup and assign it to at least one of its routes.")
                }
            } else {
                dlog?.note("MNRouteGroup route: [\(route.method) \(route.path.string)] has no routeInfo! call .metadata(...) in the RouteBuilder declr.")
            }
        }
        
        if newGroups.count == 0 {
            dlog?.note("MNRouteGroup found 0 result groups!")
        } else {
            dlog?.info("MNRouteGroup found \(newGroups.count) groups: \(newGroups.sortedKeys)")
        }
        
        self.groups = newGroups
        
        return newGroups
    }
    
    // MARK: CustomDebugStringConvertible
    public var debugDescription: String {
        return "<MNRouteGroup tag: \(self.groupTag) product: \(self.productType)>"
    }
    
    // MARK: HasHable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(groupTag)
        hasher.combine(productType)
        // NOTE: IGNORE and DO NOT user title & description in comparison or hasshing!
    }
    
    // MARK: Equatable
    // MARK: Equatable
    public static func ==(lhs:MNRouteGroup, rhs:MNRouteGroup)->Bool {
        // NOTE: IGNORE and DO NOT user title & description in comparison or hasshing!
        return lhs.hashValue == rhs.hashValue
    }
    
}
