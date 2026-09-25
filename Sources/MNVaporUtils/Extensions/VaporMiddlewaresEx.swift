//
//  VaporMiddlewaresEx.swift
//
//
// Created by Ido Rabin for Bricks on 17/1/2024.

import Foundation
import Vapor
import MNUtils


public extension Vapor.Middleware {
    
    static func mnDefaultMiddlewareNameTransform(_ name:String)->String {
        return MNDBUtils.mnDefaultDBTypeNameTransform("\(name)")
    }
    
    var name : String {
        return Self.mnDefaultMiddlewareNameTransform("\(self)")
    }
}

public extension Vapor.Middlewares {
    // MARK: Main Work Func:
    private func internal_getUncaseMiddleware(named name:String)->(any Middleware)? {
        // https://ifcaselet.com/using-mirror-to-test-private-properties/
        let mirror = Mirror(reflecting: self)
        let arr = mirror.descendant("storage") as! [Middleware]
        
        // Use both name and raw saved value for comparisons
        let names : [String] = [
            name,
            MNDBUtils.mnDefaultDBTypeNameTransform(name)
        ]
        
        // Find first middleware matching either .name propery or the raw "class" name
        return arr.first { middle in
            let str1 = "\(type(of:middle))"
            let middleNames = [
                str1,
                MNDBUtils.mnDefaultDBTypeNameTransform(str1)
            ]
            return middleNames.intersection(with: names).count > 0
        }
    }
    
    var all : [Middleware] {
        let mirror = Mirror(reflecting: self)
        let arr = mirror.descendant("storage") as! [Middleware]
        return arr
    }
    
    // MARK: Conveniences and wrappers:
    func hasMiddleware(named name:String)->Bool {
        return internal_getUncaseMiddleware(named: name) != nil
    }
    
    func hasMiddleware<T:Middleware>(ofType:T.Type)->Bool {
        return self.hasMiddleware(named: "\(T.self)")
    }
    
    func middleware<T:Middleware>(named name:String)->T? {
        return internal_getUncaseMiddleware(named: name) as? T
    }
    
    func findMiddleware<T:Middleware>(named name:String)->T? {
        return self.middleware(named: name)
    }
    
    func getMiddleware<T:Middleware>(named name:String)->T? {
        return self.middleware(named: name)
    }
    
    func middleware<T:Middleware>(ofType:T.Type)->T? {
        // https://ifcaselet.com/using-mirror-to-test-private-properties/
        let mirror = Mirror(reflecting: self)
        let arr = mirror.descendant("storage") as! [Middleware]
        return arr.first { middle in
            middle is T
        } as? T
    }
    
    func findMiddleware<T:Middleware>(ofType:T.Type)->T? {
        let result : T? = self.middleware(ofType: ofType)
        return result
    }
    
    func getMiddleware<T:Middleware>(ofType:T.Type)->T? {
        let result : T? = self.middleware(ofType: ofType)
        return result
    }
}
