# Agent Guidelines

Rules for AI agents working on this project.

## Boundaries

### You CAN:
- Modify files ONLY in your assigned module directory
- Add new files to your assigned module
- Add tests to your assigned test directory
- Import from modules you depend on (see ARCHITECTURE.md)

### You CANNOT:
- Modify files in other modules
- Change Package.swift
- Modify TUICore (it's complete)
- Add external dependencies
- Create circular dependencies

## Module Assignments

When assigned to a module, you own:
```
Sources/<ModuleName>/     <- Your source files
Tests/<ModuleName>Tests/  <- Your test files
```

## Development Process

1. **Read First**
   - Read ARCHITECTURE.md to understand the project
   - Read INTERFACES.md to understand your module's contract
   - Read existing code in your module

2. **TDD - Tests First**
   - Write failing tests that define expected behavior
   - Run: `swift test --filter <YourModule>`
   - Implement code to make tests pass

3. **Interface Compliance**
   - Your public API MUST match INTERFACES.md
   - If interface is incomplete, implement what's there first
   - Do not change interface signatures without coordination

4. **Code Quality**
   - All types that might be used cross-module: `public`
   - Sendable compliance where possible
   - No force unwrapping in production code
   - Handle errors gracefully

## Import Rules

```swift
// Layer 2 modules can only import:
import TUICore

// Layer 3 modules can import:
import TUICore
import <Their Layer 2 dependencies>  // See ARCHITECTURE.md

// Example: TUIStyle can import:
import TUICore
import TUIHTMLParser
import TUICSSParser
```

## Git Workflow

After completing work:
1. Ensure all tests pass: `swift test --filter <YourModule>`
2. Stage your changes: `git add Sources/<YourModule> Tests/<YourModule>Tests`
3. Commit with clear message describing what you implemented

## Verification Checklist

Before marking work complete:
- [ ] All tests pass
- [ ] No compilation errors
- [ ] Public API matches INTERFACES.md
- [ ] No imports from modules you don't depend on
- [ ] No modifications to files outside your module

## Common Pitfalls

1. **NSLock not available**: Use `import Foundation` or use a different locking mechanism
2. **Sendable warnings**: Mark classes as `@unchecked Sendable` if you handle thread safety manually
3. **Circular imports**: Never import a module that imports you
4. **Missing exports**: Make sure types are `public` if other modules need them

## Getting Help

If you're stuck:
1. Re-read the interface contract
2. Check how similar code works in other modules
3. Look at test files for usage examples
4. Ask for clarification rather than guessing
