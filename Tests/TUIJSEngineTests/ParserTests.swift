import Testing
@testable import TUIJSEngine

/// Helper function to parse code into statements
func parse(_ code: String) -> [Statement] {
    var lexer = Lexer(source: code)
    var parser = Parser(tokens: lexer.scanTokens())
    return parser.parse()
}

@Suite("Parser Tests")
struct ParserTests {

    // MARK: - Variable Declarations

    @Test func testParseLetDeclaration() {
        let stmts = parse("let x = 5;")

        #expect(stmts.count == 1)
        if case .variableDeclaration(let kind, let declarations) = stmts[0] {
            #expect(kind == .let)
            #expect(declarations.count == 1)
            #expect(declarations[0].name == "x")
            if case .literal(.number(5)) = declarations[0].initializer {
                // OK
            } else {
                Issue.record("Expected number literal 5")
            }
        } else {
            Issue.record("Expected variable declaration")
        }
    }

    @Test func testParseVarDeclaration() {
        let stmts = parse("var name = 'hello';")

        #expect(stmts.count == 1)
        if case .variableDeclaration(let kind, let declarations) = stmts[0] {
            #expect(kind == .var)
            #expect(declarations[0].name == "name")
            if case .literal(.string("hello")) = declarations[0].initializer {
                // OK
            } else {
                Issue.record("Expected string literal 'hello'")
            }
        } else {
            Issue.record("Expected variable declaration")
        }
    }

    @Test func testParseConstDeclaration() {
        let stmts = parse("const PI = 3.14;")

        #expect(stmts.count == 1)
        if case .variableDeclaration(let kind, _) = stmts[0] {
            #expect(kind == .const)
        } else {
            Issue.record("Expected const declaration")
        }
    }

    @Test func testParseMultipleDeclarations() {
        let stmts = parse("let x = 1, y = 2;")

        #expect(stmts.count == 1)
        if case .variableDeclaration(_, let declarations) = stmts[0] {
            #expect(declarations.count == 2)
            #expect(declarations[0].name == "x")
            #expect(declarations[1].name == "y")
        } else {
            Issue.record("Expected variable declaration")
        }
    }

    // MARK: - Function Declarations

    @Test func testParseFunctionDeclaration() {
        let code = "function add(a, b) { return a + b; }"
        let stmts = parse(code)

        #expect(stmts.count == 1)
        if case .functionDeclaration(let name, let params, let body) = stmts[0] {
            #expect(name == "add")
            #expect(params == ["a", "b"])
            #expect(body.count == 1)
        } else {
            Issue.record("Expected function declaration")
        }
    }

    @Test func testParseFunctionNoParams() {
        let code = "function sayHello() { return 'hello'; }"
        let stmts = parse(code)

        if case .functionDeclaration(let name, let params, _) = stmts[0] {
            #expect(name == "sayHello")
            #expect(params.isEmpty)
        } else {
            Issue.record("Expected function declaration")
        }
    }

    // MARK: - Arrow Functions

    @Test func testParseArrowFunctionExpression() {
        let code = "const double = x => x * 2;"
        let stmts = parse(code)

        #expect(stmts.count == 1)
        if case .variableDeclaration(_, let declarations) = stmts[0] {
            if case .arrowFunction(let params, let body) = declarations[0].initializer {
                #expect(params == ["x"])
                if case .expression(let expr) = body {
                    if case .binary(_, let op, _) = expr {
                        #expect(op == "*")
                    } else {
                        Issue.record("Expected binary expression")
                    }
                } else {
                    Issue.record("Expected expression body")
                }
            } else {
                Issue.record("Expected arrow function")
            }
        } else {
            Issue.record("Expected variable declaration")
        }
    }

    @Test func testParseArrowFunctionMultipleParams() {
        let code = "const add = (a, b) => a + b;"
        let stmts = parse(code)

        if case .variableDeclaration(_, let declarations) = stmts[0] {
            if case .arrowFunction(let params, _) = declarations[0].initializer {
                #expect(params == ["a", "b"])
            } else {
                Issue.record("Expected arrow function")
            }
        } else {
            Issue.record("Expected variable declaration")
        }
    }

    @Test func testParseArrowFunctionBlock() {
        let code = "const greet = (name) => { return 'Hello ' + name; };"
        let stmts = parse(code)

        if case .variableDeclaration(_, let declarations) = stmts[0] {
            if case .arrowFunction(let params, let body) = declarations[0].initializer {
                #expect(params == ["name"])
                if case .block(let blockStmts) = body {
                    #expect(blockStmts.count == 1)
                } else {
                    Issue.record("Expected block body")
                }
            } else {
                Issue.record("Expected arrow function")
            }
        } else {
            Issue.record("Expected variable declaration")
        }
    }

    // MARK: - Expressions

    @Test func testParseArithmeticExpression() {
        let code = "2 + 3 * 4;"
        let stmts = parse(code)

        // Should parse as 2 + (3 * 4) due to precedence
        if case .expression(let expr) = stmts[0] {
            if case .binary(let left, let op, let right) = expr {
                #expect(op == "+")
                if case .literal(.number(2)) = left {
                    // OK
                } else {
                    Issue.record("Expected left to be 2")
                }
                if case .binary(_, let innerOp, _) = right {
                    #expect(innerOp == "*")
                } else {
                    Issue.record("Expected right to be binary with *")
                }
            } else {
                Issue.record("Expected binary expression")
            }
        } else {
            Issue.record("Expected expression statement")
        }
    }

    @Test func testParseComparisonExpression() {
        let code = "x > 5;"
        let stmts = parse(code)

        if case .expression(let expr) = stmts[0] {
            if case .binary(_, let op, _) = expr {
                #expect(op == ">")
            } else {
                Issue.record("Expected binary expression")
            }
        } else {
            Issue.record("Expected expression statement")
        }
    }

    @Test func testParseLogicalExpression() {
        let code = "x && y || z;"
        let stmts = parse(code)

        // Should parse as (x && y) || z
        if case .expression(let expr) = stmts[0] {
            if case .logical(let left, let op, _) = expr {
                #expect(op == "||")
                if case .logical(_, let innerOp, _) = left {
                    #expect(innerOp == "&&")
                } else {
                    Issue.record("Expected inner logical &&")
                }
            } else {
                Issue.record("Expected logical expression")
            }
        } else {
            Issue.record("Expected expression statement")
        }
    }

    @Test func testParseAssignment() {
        let code = "x = 5;"
        let stmts = parse(code)

        if case .expression(let expr) = stmts[0] {
            if case .assignment(let target, let op, let value) = expr {
                #expect(op == "=")
                if case .identifier("x") = target {
                    // OK
                } else {
                    Issue.record("Expected identifier x")
                }
                if case .literal(.number(5)) = value {
                    // OK
                } else {
                    Issue.record("Expected number 5")
                }
            } else {
                Issue.record("Expected assignment")
            }
        } else {
            Issue.record("Expected expression statement")
        }
    }

    @Test func testParseTernary() {
        let code = "x > 0 ? 'positive' : 'non-positive';"
        let stmts = parse(code)

        if case .expression(let expr) = stmts[0] {
            if case .conditional(let test, let consequent, let alternate) = expr {
                if case .binary(_, ">", _) = test {
                    // OK
                } else {
                    Issue.record("Expected comparison in test")
                }
                if case .literal(.string("positive")) = consequent {
                    // OK
                } else {
                    Issue.record("Expected 'positive' consequent")
                }
                if case .literal(.string("non-positive")) = alternate {
                    // OK
                } else {
                    Issue.record("Expected 'non-positive' alternate")
                }
            } else {
                Issue.record("Expected conditional")
            }
        } else {
            Issue.record("Expected expression statement")
        }
    }

    // MARK: - Call Expressions

    @Test func testParseFunctionCall() {
        let code = "add(2, 3);"
        let stmts = parse(code)

        if case .expression(let expr) = stmts[0] {
            if case .call(let callee, let args) = expr {
                if case .identifier("add") = callee {
                    // OK
                } else {
                    Issue.record("Expected callee 'add'")
                }
                #expect(args.count == 2)
            } else {
                Issue.record("Expected call expression")
            }
        } else {
            Issue.record("Expected expression statement")
        }
    }

    @Test func testParseMethodCall() {
        let code = "console.log('hello');"
        let stmts = parse(code)

        if case .expression(let expr) = stmts[0] {
            if case .call(let callee, let args) = expr {
                if case .member(let obj, let prop, _) = callee {
                    if case .identifier("console") = obj {
                        #expect(prop == "log")
                    } else {
                        Issue.record("Expected console object")
                    }
                } else {
                    Issue.record("Expected member expression")
                }
                #expect(args.count == 1)
            } else {
                Issue.record("Expected call expression")
            }
        } else {
            Issue.record("Expected expression statement")
        }
    }

    // MARK: - Arrays and Objects

    @Test func testParseArrayLiteral() {
        let code = "let arr = [1, 2, 3];"
        let stmts = parse(code)

        if case .variableDeclaration(_, let declarations) = stmts[0] {
            if case .array(let elements) = declarations[0].initializer {
                #expect(elements.count == 3)
            } else {
                Issue.record("Expected array literal")
            }
        } else {
            Issue.record("Expected variable declaration")
        }
    }

    @Test func testParseObjectLiteral() {
        let code = "let obj = { name: 'test', value: 42 };"
        let stmts = parse(code)

        if case .variableDeclaration(_, let declarations) = stmts[0] {
            if case .object(let properties) = declarations[0].initializer {
                #expect(properties.count == 2)
                #expect(properties[0].key == "name")
                #expect(properties[1].key == "value")
            } else {
                Issue.record("Expected object literal")
            }
        } else {
            Issue.record("Expected variable declaration")
        }
    }

    @Test func testParseMemberAccess() {
        let code = "obj.property;"
        let stmts = parse(code)

        if case .expression(let expr) = stmts[0] {
            if case .member(let obj, let prop, let computed) = expr {
                if case .identifier("obj") = obj {
                    #expect(prop == "property")
                    #expect(!computed)
                } else {
                    Issue.record("Expected obj identifier")
                }
            } else {
                Issue.record("Expected member expression")
            }
        } else {
            Issue.record("Expected expression statement")
        }
    }

    @Test func testParseComputedMemberAccess() {
        let code = "arr[0];"
        let stmts = parse(code)

        if case .expression(let expr) = stmts[0] {
            if case .member(_, let prop, let computed) = expr {
                #expect(prop == "0")
                #expect(computed)
            } else {
                Issue.record("Expected member expression")
            }
        } else {
            Issue.record("Expected expression statement")
        }
    }

    // MARK: - Control Flow

    @Test func testParseIfStatement() {
        let code = "if (x > 0) { return x; }"
        let stmts = parse(code)

        if case .ifStatement(let test, let consequent, let alternate) = stmts[0] {
            if case .binary(_, ">", _) = test {
                // OK
            } else {
                Issue.record("Expected comparison")
            }
            if case .block(_) = consequent {
                // OK
            } else {
                Issue.record("Expected block")
            }
            #expect(alternate == nil)
        } else {
            Issue.record("Expected if statement")
        }
    }

    @Test func testParseIfElseStatement() {
        let code = "if (x > 0) { return 1; } else { return 0; }"
        let stmts = parse(code)

        if case .ifStatement(_, _, let alternate) = stmts[0] {
            #expect(alternate != nil)
            if case .block(_) = alternate {
                // OK
            } else {
                Issue.record("Expected else block")
            }
        } else {
            Issue.record("Expected if statement")
        }
    }

    @Test func testParseForLoop() {
        let code = "for (let i = 0; i < 10; i++) { x = x + i; }"
        let stmts = parse(code)

        if case .forStatement(let init_, let test, let update, let body) = stmts[0] {
            #expect(init_ != nil)
            #expect(test != nil)
            #expect(update != nil)
            if case .block(_) = body {
                // OK
            } else {
                Issue.record("Expected block body")
            }
        } else {
            Issue.record("Expected for statement")
        }
    }

    @Test func testParseWhileLoop() {
        let code = "while (x > 0) { x--; }"
        let stmts = parse(code)

        if case .whileStatement(let test, let body) = stmts[0] {
            if case .binary(_, ">", _) = test {
                // OK
            } else {
                Issue.record("Expected comparison")
            }
            if case .block(_) = body {
                // OK
            } else {
                Issue.record("Expected block body")
            }
        } else {
            Issue.record("Expected while statement")
        }
    }

    @Test func testParseBreakContinue() {
        let stmts = parse("break;")
        if case .breakStatement = stmts[0] {
            // OK
        } else {
            Issue.record("Expected break statement")
        }

        let stmts2 = parse("continue;")
        if case .continueStatement = stmts2[0] {
            // OK
        } else {
            Issue.record("Expected continue statement")
        }
    }

    // MARK: - Unary and Update Expressions

    @Test func testParseUnaryMinus() {
        let code = "-x;"
        let stmts = parse(code)

        if case .expression(let expr) = stmts[0] {
            if case .unary(let op, _, let prefix) = expr {
                #expect(op == "-")
                #expect(prefix)
            } else {
                Issue.record("Expected unary expression")
            }
        } else {
            Issue.record("Expected expression statement")
        }
    }

    @Test func testParseLogicalNot() {
        let code = "!flag;"
        let stmts = parse(code)

        if case .expression(let expr) = stmts[0] {
            if case .unary(let op, _, _) = expr {
                #expect(op == "!")
            } else {
                Issue.record("Expected unary expression")
            }
        } else {
            Issue.record("Expected expression statement")
        }
    }

    @Test func testParsePrefixIncrement() {
        let code = "++x;"
        let stmts = parse(code)

        if case .expression(let expr) = stmts[0] {
            if case .update(let op, _, let prefix) = expr {
                #expect(op == "++")
                #expect(prefix)
            } else {
                Issue.record("Expected update expression")
            }
        } else {
            Issue.record("Expected expression statement")
        }
    }

    @Test func testParsePostfixDecrement() {
        let code = "x--;"
        let stmts = parse(code)

        if case .expression(let expr) = stmts[0] {
            if case .update(let op, _, let prefix) = expr {
                #expect(op == "--")
                #expect(!prefix)
            } else {
                Issue.record("Expected update expression")
            }
        } else {
            Issue.record("Expected expression statement")
        }
    }

    // MARK: - New Expression

    @Test func testParseNewExpression() {
        let code = "new Array(10);"
        let stmts = parse(code)

        if case .expression(let expr) = stmts[0] {
            if case .new(let callee, let args) = expr {
                if case .identifier("Array") = callee {
                    #expect(args.count == 1)
                } else {
                    Issue.record("Expected Array callee")
                }
            } else {
                Issue.record("Expected new expression")
            }
        } else {
            Issue.record("Expected expression statement")
        }
    }

    // MARK: - Typeof

    @Test func testParseTypeof() {
        let code = "typeof x;"
        let stmts = parse(code)

        if case .expression(let expr) = stmts[0] {
            if case .typeof(let operand) = expr {
                if case .identifier("x") = operand {
                    // OK
                } else {
                    Issue.record("Expected identifier x")
                }
            } else {
                Issue.record("Expected typeof expression")
            }
        } else {
            Issue.record("Expected expression statement")
        }
    }
}
