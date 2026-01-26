#!/usr/bin/env swift

// A standalone test script for TUIHTMLParser
// Run with: swift TestHTMLParser.swift

import Foundation

// This needs to be run from within the package context
// For now, we'll create a simple test that verifies the module compiles

print("=== TUIHTMLParser Standalone Test ===")
print("")
print("Building the module...")

// Use shell command to build
let buildTask = Process()
buildTask.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
buildTask.arguments = ["build", "--target", "TUIHTMLParser"]
buildTask.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

let buildPipe = Pipe()
buildTask.standardOutput = buildPipe
buildTask.standardError = buildPipe

try? buildTask.run()
buildTask.waitUntilExit()

let buildOutput = String(data: buildPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

if buildTask.terminationStatus == 0 {
    print("Build: PASSED")
} else {
    print("Build: FAILED")
    print(buildOutput)
    exit(1)
}

print("")
print("Module compiles successfully!")
print("To run full tests, fix other modules or use: swift test --filter TUIHTMLParserTests")
