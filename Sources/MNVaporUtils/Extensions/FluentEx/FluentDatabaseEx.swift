//
//  FluentDatabaseEx.swift
//  
//
// Created by Ido Rabin for Bricks on 17/1/2024.

import Foundation
import Logging
import Fluent
import MNUtils

fileprivate let dlog: Logger? = Logger(label: "FluentDatabaseEx")

// FluentKit
public extension Fluent.Database {
    
    /// .read() or .create() an enum type in the DB, according to the need (creates if does not already exists)
    ///  NOTE: Remember that @Enum(...) fluent field wrapper!
    /// - Parameters:
    ///   - enumName: name of the enum
    ///   - enumAllCases: all cases of the enum.
    /// - Returns: EventLoopFuture<DatabaseSchema.DataType> the data type schema for use in other migrations, during .prepare functions.
    private func createOrGetEnumType(enumName:String, enumAllCases:[String] )->EventLoopFuture<DatabaseSchema.DataType> {
        // Read the enum type if it exists
        dlog?.info("createOrGetEnumType for enum: [\(enumName)] got cases: \(enumAllCases.descriptionsJoined)")

        // Create a builder by this name
        let enumBuilder: EnumBuilder = self.enum(enumName)
        
        // Get an existing result or Error:
        return enumBuilder.read().flatMapAlways({ result in
            switch result {
            case .success(let dataType):
                // NOTE: If this fails with "type does not exist" we probably have an inconsistancey problem between the _fluent tables and the type definition in PSQL internally.
                switch dataType {
                case .enum(let anEnum):
                    // Make sure we have cases...
                    let existingAllCases = anEnum.cases.uniqueElements().sorted()
                    let newAllCases = enumAllCases.uniqueElements().sorted()
                    if existingAllCases == newAllCases {
                        
                        // No action: already exists
                        // Exactly the same cases in the existing and new Enum cases: no change needed!
                        return self.eventLoop.makeSucceededFuture(result.successValue!)
                        
                    } else {
                        var action : DatabaseEnum.Action? = .create
                        
                        // Not all cases exist / difference requires update:
                        let toRemove = existingAllCases.removing(objects: newAllCases)
                        let toAdd = newAllCases.removing(objects: existingAllCases)
                        
                        // Determine which action to take:
                        switch (existingAllCases.count, newAllCases.count) {
                        case (0, _):
                            action = .create
                        case (_, 0):
                            action = .delete
                        case (_, _):
                            if toAdd.count == 0 && toRemove.count == 0 {
                                // Exists needs no changes at all
                                action = nil
                            } else {
                                action = .update
                            }
                            
                        }

                        // execute the ection
                        if let action = action {
                            
                            // Remove cases from Enum in DB:
                            for remov in toRemove {
                                _ = enumBuilder.deleteCase(remov)
                            }
                            // Add cases to Enum in DB:
                            for add in toAdd {
                                _ = enumBuilder.case(add)
                            }
                            
                            // Execute transaction
                            switch action {
                            case .create:
                                return enumBuilder.create()
                            case .update:
                                return enumBuilder.update()
                            case .delete:
                                return enumBuilder.update() // .delete()
                            }
                        } else {
                            // No action needed: (no transaction needed for the DB enum)
                            return eventLoop.makeSucceededFuture(dataType)
                        }
                    }
                default:
                    let err = MNError(code:.db_unknown, reason: "createOrGetEnumType [\(enumName)] schema type is not Enum")
                    // throw err
                    return eventLoop.makeFailedFuture(err) // <DatabaseSchema.DataType>
                }
            case .failure(let error):
                // Handle only errors: in this case, we need to create a new enum type and add its cases and return that
                dlog?.info("createOrGetEnumType [\(enumName)] was not found: \(String(describing: error)). will creeate new")
                let enumBuilder : EnumBuilder = self.enum(enumName)
                for caseName in enumAllCases.uniqueElements() {
                    _ = enumBuilder.case(caseName)
                }
                return enumBuilder.create() // enumBuilder has no .ignoreExisting()
            }
        })
    }
    
    func createOrGetCaseIterableEnumType<T:CaseIterable>(anEnumType:T.Type )->EventLoopFuture<DatabaseSchema.DataType> {
        // TODO: use MNDBUtils
        var enumName = MNDBUtils.mnDefaultDBTypeNameTransform("\(T.self)")
        if let aT = T.self as? any MNDBEnum {
            enumName = aT.dbEnumName
        }
        let allCases : [String] = T.allCases.map { acaseVal in
            var result = "\(acaseVal)"
            if let val = acaseVal as? any MNDBEnum {
                result = val.dbCaseName
            } else if let val = acaseVal as? any RawRepresentable<String> {
                result = val.rawValue
            }
            return result
        }
        // dlog?.note("createOrGetCaseIterableEnumType: Enum type \(T.self) should conform to MNDBEnum")
        return self.createOrGetEnumType(enumName: enumName, enumAllCases: allCases)
    }
    
    func asyncCreateOrGetCaseIterableEnumType<T:CaseIterable>(anEnumType:T.Type ) async throws-> DatabaseSchema.DataType {
        let result : DatabaseSchema.DataType = try await createOrGetCaseIterableEnumType(anEnumType: anEnumType).get()
        return result
    }
    
    func deleteEnumType<T>(anEnumType:T.Type ) async throws {
        var enumName = MNDBUtils.mnDefaultDBTypeNameTransform("\(T.self)")
        if let aT = T.self as? any MNDBEnum {
            enumName = aT.dbEnumName
        }
        try await self.enum(enumName).delete()
    }
}
