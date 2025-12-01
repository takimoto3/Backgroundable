import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftBasicFormat
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftOperators

struct SimpleDiagnosticMessage: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity
}

public struct BackgroundablePropertyMacro: MemberMacro {
    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [DeclSyntax] {
    
        guard declaration.as(ClassDeclSyntax.self) != nil else {
            let message = SimpleDiagnosticMessage(
                message: "@BackgroundableProperty macro must be applied to a class.",
                diagnosticID: MessageID(domain: "BackgroundableProperty", id: "TargetTypeNotClass"),
                severity: .error
            )
            context.diagnose(Diagnostic(node: Syntax(node), message: message))
            return []
        }

        guard let name = node.argumentExpression(for: "name")?.asString() else {
            let message = SimpleDiagnosticMessage(
                message: "Required argument 'name' is missing in @BackgroundableProperty macro.",
                diagnosticID: MessageID(domain: "BackgroundableProperty", id: "nameArgumentMissing"),
                severity: .error
            )
            context.diagnose(Diagnostic(node: Syntax(node), message: message))
            return []
        }
            
        let identifier = "_" + name
                
        let generatedCode = VariableDeclSyntax(
            modifiers: [.init(name: .keyword(.private))],
            bindingSpecifier: .keyword(.var),
            bindings: PatternBindingListSyntax {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier(identifier)),
                    typeAnnotation: TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: .identifier("UIBackgroundTaskIdentifier"))),
                    initializer: InitializerClauseSyntax(value: MemberAccessExprSyntax(name: "invalid"))
                )
            }
        )
        return [DeclSyntax(generatedCode)]
    }
}

public struct BackgroundableMacro: BodyMacro {
    public static func expansion(of node: SwiftSyntax.AttributeSyntax, providingBodyFor declaration: some SwiftSyntax.DeclSyntaxProtocol & SwiftSyntax.WithOptionalCodeBlockSyntax, in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.CodeBlockItemSyntax] {
        
        guard let body = declaration.body else {
            let message = SimpleDiagnosticMessage(
                message: "@Backgroundable can only be applied to functions that have a body.",
                diagnosticID: MessageID(domain: "Backgroundable", id: "requiresBody"),
                severity: .error
            )
            context.diagnose(Diagnostic(node: Syntax(node), message: message))
            return []
        }
        
        let expirationFunc = node.argumentExpression(for: "expirationFunc")?.asString()
        let withName = node.argumentExpression(for: "withName")?.asString()
        let propertyName = node.argumentExpression(for: "propertyName")?.asString()
        
        let baseIdentifier = (propertyName != nil) ? propertyName! : "backgroundTaskID"
        let identifier = "_" + baseIdentifier
        
        let targetReference: ExprSyntax
        if (propertyName == nil) {
            targetReference = ExprSyntax(
                DeclReferenceExprSyntax(baseName: .identifier(identifier))
            )
        } else {
            targetReference = ExprSyntax(
                MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .identifier("self")),
                    name: .identifier(identifier)
                )
            )
        }
        let endBackgroundTaskStatement = CodeBlockItemSyntax(item: .expr(ExprSyntax(FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .identifier("UIApplication")),
                    period: .periodToken(),
                    declName: DeclReferenceExprSyntax(baseName: .identifier("shared"))
                ),
                period: .periodToken(),
                declName: DeclReferenceExprSyntax(baseName: .identifier("endBackgroundTask"))
            ),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax{
                LabeledExprSyntax(expression: targetReference)
            },
            rightParen: .rightParenToken(),
        ))))
        
        let ifStatement = CodeBlockItemSyntax(item: .expr(ExprSyntax(
            IfExprSyntax(
                ifKeyword: .keyword(.if),
                conditions: ConditionElementListSyntax{
                    ConditionElementSyntax(condition: .expression(ExprSyntax(SequenceExprSyntax(
                        elements:[
                            targetReference,
                            ExprSyntax(BinaryOperatorExprSyntax(operator: .binaryOperator("!="))),
                            ExprSyntax(MemberAccessExprSyntax(name: .identifier("invalid"))),
                        ]
                    ))))
            }, body: CodeBlockSyntax(statements: [
                endBackgroundTaskStatement,
                CodeBlockItemSyntax(item: .expr(
                    ExprSyntax(
                        InfixOperatorExprSyntax(
                            leftOperand: targetReference,
                            operator: BinaryOperatorExprSyntax(operator: .equalToken()),
                            rightOperand: MemberAccessExprSyntax(name: "invalid")
                        ),
                    ),
                ))
            ]))
        )))


        var functionArguments: LabeledExprListSyntax = []
        if let withName {
            functionArguments.append(LabeledExprSyntax(
                label: "withName",
                colon: .colonToken(),
                expression: ExprSyntax(
                    StringLiteralExprSyntax(content: withName)
                ),
            ))
        }
            
        var closureBody: CodeBlockItemListSyntax = []
        if let expirationFunc {
            closureBody.append(CodeBlockItemSyntax(item: .expr(ExprSyntax(
                FunctionCallExprSyntax(
                    calledExpression:
                        MemberAccessExprSyntax(
                            base: DeclReferenceExprSyntax(baseName: .identifier("self")),
                            period: .periodToken(),
                            declName: DeclReferenceExprSyntax(baseName: .identifier(expirationFunc)),
                        ),
                    leftParen: .leftParenToken(),
                    arguments: [],
                    rightParen: .rightParenToken()
                )
            ))))
        }
        closureBody.append(ifStatement)
        let closureExpr = ClosureExprSyntax(statements:closureBody)

        let beginBackgroundTaskStatement = ExprSyntax(
            InfixOperatorExprSyntax(
                leftOperand: targetReference,
                operator: ExprSyntax(
                    BinaryOperatorExprSyntax(operator: .equalToken())
                ),
                rightOperand: ExprSyntax(FunctionCallExprSyntax(
                    calledExpression: MemberAccessExprSyntax(
                        base: MemberAccessExprSyntax(
                            base: DeclReferenceExprSyntax(baseName: .identifier("UIApplication")),
                            period: .periodToken(),
                            declName: DeclReferenceExprSyntax(baseName: .identifier("shared"))
                        ),
                        period: .periodToken(),
                        declName: DeclReferenceExprSyntax(baseName: .identifier("beginBackgroundTask"))
                    ),
                    leftParen: functionArguments.isEmpty ? nil : .leftParenToken(),
                    arguments: functionArguments.isEmpty ? [] : functionArguments,
                    rightParen: functionArguments.isEmpty ? nil : .rightParenToken(),
                    trailingClosure: closureExpr
                ))
            )
        )
        
        let variableDecl = VariableDeclSyntax(
            bindingSpecifier: .keyword(.var),
            bindings: PatternBindingListSyntax {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier(identifier)),
                    typeAnnotation: TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: .identifier("UIBackgroundTaskIdentifier"))),
                    initializer: InitializerClauseSyntax(value: MemberAccessExprSyntax(name: "invalid")),
                )
            }
        )
        
        let deferStatement = DeferStmtSyntax(body: CodeBlockSyntax(statements:[ifStatement]))

        var newBody: [CodeBlockItemSyntax] = []
        if propertyName == nil {
            newBody.append(CodeBlockItemSyntax(item: .decl(DeclSyntax(variableDecl))))
        }
        newBody.append(CodeBlockItemSyntax(item: .expr(beginBackgroundTaskStatement)))
        newBody.append(CodeBlockItemSyntax(item: .stmt(StmtSyntax(deferStatement))))
        
        return newBody + Array(body.statements)
    }
}

@main
struct BackgroundablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        BackgroundableMacro.self,
        BackgroundablePropertyMacro.self,
    ]
}
