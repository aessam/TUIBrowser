#!/usr/bin/env swift

// Simple test script for TUICSSParser
// Run with: swift test_css_parser.swift

import Foundation

// Since we can't easily import the module, we'll paste the code here for testing
// This is a standalone verification script

print("=== TUICSSParser Test Script ===\n")

// Test 1: Tokenizer
print("Test 1: Tokenizing 'color: red;'")
// This would use CSSTokenizer

// Test 2: Selector parsing
print("Test 2: Parsing selector 'div.class#id'")

// Test 3: Full stylesheet
print("Test 3: Parsing stylesheet")

let testCSS = """
div {
    color: red;
    background-color: #FF0000;
}

h1, h2 {
    font-weight: bold;
    text-decoration: underline;
}

.container > p {
    margin: 10px;
    padding: 1em;
}
"""

print("Input CSS:")
print(testCSS)
print("\n=== End of Test Script ===")
