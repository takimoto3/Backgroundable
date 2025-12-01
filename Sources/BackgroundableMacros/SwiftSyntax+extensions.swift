//
//  SwiftSyntax+extensions.swift
//  Backgroundable
//  
//  Created by Masato Takimoto on 2025/11/29.
//  
//

import SwiftSyntax


extension AttributeSyntax {
    func argumentExpression(for label: String) -> ExprSyntax? {
        guard case let .argumentList(arguments) = self.arguments else {
            return nil
        }
        
        for argument in arguments {
            if argument.label?.text == label {
                return argument.expression
            }
        }
        return nil
    }
}

extension ExprSyntax {
    func asString() -> String? {
        guard let literal = self.as(StringLiteralExprSyntax.self),
              let segments = literal.segments.first?.as(StringSegmentSyntax.self) else {
            return nil
        }
        return segments.content.text
    }
    
    func asBool() -> Bool? {
        guard let literal = self.as(BooleanLiteralExprSyntax.self) else {
            return nil
        }
        switch literal.literal.text {
        case "true":
            return true
        case "false":
            return false
        default:
            return nil
        }
    }
}
