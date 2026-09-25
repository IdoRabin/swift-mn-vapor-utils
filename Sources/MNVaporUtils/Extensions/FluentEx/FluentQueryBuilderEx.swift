//
//  FluentQueryBuilderEx.swift
//  
//
// Created by Ido Rabin for Bricks on 17/1/2024.

import Foundation
import FluentKit
import MNUtils

public extension QueryBuilder /* extensions */ {
    func top(_ amount:Int = 1) async throws -> [Model] {
        guard amount > 0 else {
            throw MNError(code:.db_failed_query, reason:"QueryBuilder.top(Int) must recieve a value bigger than 0")
        }
        return try await top(UInt(amount))
    }
    func top(_ amount:UInt = 1) async throws -> [Model] {
        return try await self.range(upper: Swift.max(Int(amount) - 1, 1)).all().get()
    }
    
    // Filter siblings that contain any of a given collection of property values
    @discardableResult
    func filter<
        // Generics
        Field: QueryableProperty,
        To: FluentKit.Model,
        Through: FluentKit.Model,
        Values: Collection<Field.Value>
    >(
        // Func parameters
        siblings: KeyPath<Model, SiblingsProperty<Model, To, Through>>,
        _ fieldKeyPath: KeyPath<To, Field>,
        subset: Values,
        inverse: Bool = false
    ) -> Self
    where Field.Model == To, Values.Element == Field.Value {
        self
            .join(siblings: siblings)
            .filter(
                .extendedPath(
                    To.path(for: fieldKeyPath),
                    schema: To.schemaOrAlias,
                    space: nil
                ),
                .subset(inverse: inverse),
                .array(subset.map { .bind($0) })
            )
    }
}
