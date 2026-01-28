// TUIHTMLParser - HTML Tokenizer
// State machine tokenizer following simplified WHATWG spec

import TUICore
import Foundation

/// HTML Tokenizer state machine
public final class HTMLTokenizer: @unchecked Sendable {
    /// Tokenizer states
    private enum State {
        case data
        case tagOpen
        case endTagOpen
        case tagName
        case beforeAttributeName
        case attributeName
        case afterAttributeName
        case beforeAttributeValue
        case attributeValueDoubleQuoted
        case attributeValueSingleQuoted
        case attributeValueUnquoted
        case afterAttributeValueQuoted
        case selfClosingStartTag
        case bogusComment
        case markupDeclarationOpen
        case comment
        case commentStart
        case commentStartDash
        case commentEnd
        case commentEndDash
        case doctype
        case beforeDoctypeName
        case doctypeName
        case afterDoctypeName
        case characterReference
        case namedCharacterReference
        case numericCharacterReference
        case hexCharacterReferenceStart
        case decimalCharacterReferenceStart
        case hexCharacterReference
        case decimalCharacterReference
        case numericCharacterReferenceEnd
    }

    private let input: [Character]
    private var position: Int = 0
    private var state: State = .data
    private var returnState: State = .data
    private var tokens: [HTMLToken] = []

    // Current token building
    private var currentTagName: String = ""
    private var currentTagAttributes: [HTMLAttribute] = []
    private var currentTagSelfClosing: Bool = false
    private var isEndTag: Bool = false

    private var currentAttributeName: String = ""
    private var currentAttributeValue: String = ""

    private var currentCommentData: String = ""
    private var currentDoctypeName: String = ""

    private var temporaryBuffer: String = ""
    private var characterReferenceCode: UInt32 = 0

    // Character buffer for coalescing text
    private var characterBuffer: String = ""

    public init(_ html: String) {
        self.input = Array(html)
    }

    /// Tokenize the input and return all tokens
    public func tokenize() -> [HTMLToken] {
        tokens = []
        position = 0
        state = .data
        characterBuffer = ""

        var iterations = 0
        // Keep the tokenizer from spinning forever on malformed input.
        // Cap work to a reasonable multiple of input size.
        let iterationLimit = min(1_000_000, max(200_000, input.count * 5))
        let deadline = Date().addingTimeInterval(2.0) // hard wall-clock cap

        while position < input.count && iterations < iterationLimit {
            if Date() >= deadline {
                break
            }
            let before = position
            let stateBefore = state

            processState()

            // Safety guard: only force progress if neither the state nor position changed
            if position == before && state == stateBefore {
                position += 1
            }

            iterations += 1
        }

        // If we bailed due to iteration limit, ensure we still emit what we have
        state = .data

        flushCharacterBuffer()
        tokens.append(.eof)
        return tokens
    }

    // MARK: - State Processing

    private func processState() {
        switch state {
        case .data:
            processDataState()
        case .tagOpen:
            processTagOpenState()
        case .endTagOpen:
            processEndTagOpenState()
        case .tagName:
            processTagNameState()
        case .beforeAttributeName:
            processBeforeAttributeNameState()
        case .attributeName:
            processAttributeNameState()
        case .afterAttributeName:
            processAfterAttributeNameState()
        case .beforeAttributeValue:
            processBeforeAttributeValueState()
        case .attributeValueDoubleQuoted:
            processAttributeValueDoubleQuotedState()
        case .attributeValueSingleQuoted:
            processAttributeValueSingleQuotedState()
        case .attributeValueUnquoted:
            processAttributeValueUnquotedState()
        case .afterAttributeValueQuoted:
            processAfterAttributeValueQuotedState()
        case .selfClosingStartTag:
            processSelfClosingStartTagState()
        case .bogusComment:
            processBogusCommentState()
        case .markupDeclarationOpen:
            processMarkupDeclarationOpenState()
        case .comment:
            processCommentState()
        case .commentStart:
            processCommentStartState()
        case .commentStartDash:
            processCommentStartDashState()
        case .commentEnd:
            processCommentEndState()
        case .commentEndDash:
            processCommentEndDashState()
        case .doctype:
            processDoctypeState()
        case .beforeDoctypeName:
            processBeforeDoctypeNameState()
        case .doctypeName:
            processDoctypeNameState()
        case .afterDoctypeName:
            processAfterDoctypeNameState()
        case .characterReference:
            processCharacterReferenceState()
        case .namedCharacterReference:
            processNamedCharacterReferenceState()
        case .numericCharacterReference:
            processNumericCharacterReferenceState()
        case .hexCharacterReferenceStart:
            processHexCharacterReferenceStartState()
        case .decimalCharacterReferenceStart:
            processDecimalCharacterReferenceStartState()
        case .hexCharacterReference:
            processHexCharacterReferenceState()
        case .decimalCharacterReference:
            processDecimalCharacterReferenceState()
        case .numericCharacterReferenceEnd:
            processNumericCharacterReferenceEndState()
        }
    }

    // MARK: - Data State

    private func processDataState() {
        guard let char = consumeNextChar() else {
            flushCharacterBuffer()
            return
        }

        switch char {
        case "&":
            returnState = .data
            state = .characterReference
        case "<":
            flushCharacterBuffer()
            state = .tagOpen
        default:
            characterBuffer.append(char)
        }
    }

    // MARK: - Tag Open State

    private func processTagOpenState() {
        guard let char = consumeNextChar() else {
            characterBuffer.append("<")
            state = .data
            return
        }

        switch char {
        case "!":
            state = .markupDeclarationOpen
        case "/":
            state = .endTagOpen
        case _ where char.isLetter:
            currentTagName = ""
            currentTagAttributes = []
            currentTagSelfClosing = false
            isEndTag = false
            reconsumeIn(.tagName)
        case "?":
            currentCommentData = ""
            state = .bogusComment
        default:
            characterBuffer.append("<")
            reconsumeIn(.data)
        }
    }

    // MARK: - End Tag Open State

    private func processEndTagOpenState() {
        guard let char = consumeNextChar() else {
            characterBuffer.append("</")
            state = .data
            return
        }

        switch char {
        case _ where char.isLetter:
            currentTagName = ""
            currentTagAttributes = []
            currentTagSelfClosing = false
            isEndTag = true
            reconsumeIn(.tagName)
        case ">":
            state = .data
        default:
            currentCommentData = ""
            state = .bogusComment
        }
    }

    // MARK: - Tag Name State

    private func processTagNameState() {
        guard let char = consumeNextChar() else {
            state = .data
            return
        }

        switch char {
        case "\t", "\n", "\u{000C}", " ":
            state = .beforeAttributeName
        case "/":
            state = .selfClosingStartTag
        case ">":
            emitCurrentTag()
            state = .data
        case _ where char.isASCII && char.isUppercase:
            currentTagName.append(char.lowercased())
        default:
            currentTagName.append(char)
        }
    }

    // MARK: - Before Attribute Name State

    private func processBeforeAttributeNameState() {
        guard let char = consumeNextChar() else {
            state = .data
            return
        }

        switch char {
        case "\t", "\n", "\u{000C}", " ":
            // Ignore whitespace
            break
        case "/", ">":
            reconsumeIn(.afterAttributeName)
        case "=":
            currentAttributeName = String(char)
            currentAttributeValue = ""
            state = .attributeName
        default:
            currentAttributeName = ""
            currentAttributeValue = ""
            reconsumeIn(.attributeName)
        }
    }

    // MARK: - Attribute Name State

    private func processAttributeNameState() {
        guard let char = consumeNextChar() else {
            state = .data
            return
        }

        switch char {
        case "\t", "\n", "\u{000C}", " ", "/", ">":
            reconsumeIn(.afterAttributeName)
        case "=":
            state = .beforeAttributeValue
        case _ where char.isASCII && char.isUppercase:
            currentAttributeName.append(char.lowercased())
        default:
            currentAttributeName.append(char)
        }
    }

    // MARK: - After Attribute Name State

    private func processAfterAttributeNameState() {
        guard let char = consumeNextChar() else {
            state = .data
            return
        }

        switch char {
        case "\t", "\n", "\u{000C}", " ":
            // Ignore whitespace
            break
        case "/":
            appendCurrentAttribute()
            state = .selfClosingStartTag
        case "=":
            state = .beforeAttributeValue
        case ">":
            appendCurrentAttribute()
            emitCurrentTag()
            state = .data
        default:
            appendCurrentAttribute()
            currentAttributeName = ""
            currentAttributeValue = ""
            reconsumeIn(.attributeName)
        }
    }

    // MARK: - Before Attribute Value State

    private func processBeforeAttributeValueState() {
        guard let char = consumeNextChar() else {
            state = .data
            return
        }

        switch char {
        case "\t", "\n", "\u{000C}", " ":
            // Ignore whitespace
            break
        case "\"":
            state = .attributeValueDoubleQuoted
        case "'":
            state = .attributeValueSingleQuoted
        case ">":
            appendCurrentAttribute()
            emitCurrentTag()
            state = .data
        default:
            reconsumeIn(.attributeValueUnquoted)
        }
    }

    // MARK: - Attribute Value Double Quoted State

    private func processAttributeValueDoubleQuotedState() {
        guard let char = consumeNextChar() else {
            state = .data
            return
        }

        switch char {
        case "\"":
            appendCurrentAttribute()
            state = .afterAttributeValueQuoted
        case "&":
            returnState = .attributeValueDoubleQuoted
            state = .characterReference
        default:
            currentAttributeValue.append(char)
        }
    }

    // MARK: - Attribute Value Single Quoted State

    private func processAttributeValueSingleQuotedState() {
        guard let char = consumeNextChar() else {
            state = .data
            return
        }

        switch char {
        case "'":
            appendCurrentAttribute()
            state = .afterAttributeValueQuoted
        case "&":
            returnState = .attributeValueSingleQuoted
            state = .characterReference
        default:
            currentAttributeValue.append(char)
        }
    }

    // MARK: - Attribute Value Unquoted State

    private func processAttributeValueUnquotedState() {
        guard let char = consumeNextChar() else {
            state = .data
            return
        }

        switch char {
        case "\t", "\n", "\u{000C}", " ":
            appendCurrentAttribute()
            state = .beforeAttributeName
        case "&":
            returnState = .attributeValueUnquoted
            state = .characterReference
        case ">":
            appendCurrentAttribute()
            emitCurrentTag()
            state = .data
        default:
            currentAttributeValue.append(char)
        }
    }

    // MARK: - After Attribute Value Quoted State

    private func processAfterAttributeValueQuotedState() {
        guard let char = consumeNextChar() else {
            state = .data
            return
        }

        switch char {
        case "\t", "\n", "\u{000C}", " ":
            state = .beforeAttributeName
        case "/":
            state = .selfClosingStartTag
        case ">":
            emitCurrentTag()
            state = .data
        default:
            reconsumeIn(.beforeAttributeName)
        }
    }

    // MARK: - Self-Closing Start Tag State

    private func processSelfClosingStartTagState() {
        guard let char = consumeNextChar() else {
            state = .data
            return
        }

        switch char {
        case ">":
            currentTagSelfClosing = true
            emitCurrentTag()
            state = .data
        default:
            reconsumeIn(.beforeAttributeName)
        }
    }

    // MARK: - Bogus Comment State

    private func processBogusCommentState() {
        guard let char = consumeNextChar() else {
            emitComment()
            state = .data
            return
        }

        switch char {
        case ">":
            emitComment()
            state = .data
        default:
            currentCommentData.append(char)
        }
    }

    // MARK: - Markup Declaration Open State

    private func processMarkupDeclarationOpenState() {
        // Check for "--" (comment)
        if matchNext("--") {
            position += 2
            currentCommentData = ""
            state = .commentStart
            return
        }

        // Check for "DOCTYPE" (case-insensitive)
        if matchNextCaseInsensitive("DOCTYPE") {
            position += 7
            state = .doctype
            return
        }

        // Otherwise, bogus comment
        currentCommentData = ""
        state = .bogusComment
    }

    // MARK: - Comment States

    private func processCommentStartState() {
        guard let char = consumeNextChar() else {
            emitComment()
            state = .data
            return
        }

        switch char {
        case "-":
            state = .commentStartDash
        case ">":
            emitComment()
            state = .data
        default:
            reconsumeIn(.comment)
        }
    }

    private func processCommentStartDashState() {
        guard let char = consumeNextChar() else {
            emitComment()
            state = .data
            return
        }

        switch char {
        case "-":
            state = .commentEnd
        case ">":
            emitComment()
            state = .data
        default:
            currentCommentData.append("-")
            reconsumeIn(.comment)
        }
    }

    private func processCommentState() {
        guard let char = consumeNextChar() else {
            emitComment()
            state = .data
            return
        }

        switch char {
        case "-":
            state = .commentEndDash
        default:
            currentCommentData.append(char)
        }
    }

    private func processCommentEndDashState() {
        guard let char = consumeNextChar() else {
            emitComment()
            state = .data
            return
        }

        switch char {
        case "-":
            state = .commentEnd
        default:
            currentCommentData.append("-")
            reconsumeIn(.comment)
        }
    }

    private func processCommentEndState() {
        guard let char = consumeNextChar() else {
            emitComment()
            state = .data
            return
        }

        switch char {
        case ">":
            emitComment()
            state = .data
        case "!":
            // Comment end bang state - simplified handling
            currentCommentData.append("--!")
            state = .comment
        case "-":
            currentCommentData.append("-")
        default:
            currentCommentData.append("--")
            reconsumeIn(.comment)
        }
    }

    // MARK: - DOCTYPE States

    private func processDoctypeState() {
        guard let char = consumeNextChar() else {
            emitDoctype(forceQuirks: true)
            state = .data
            return
        }

        switch char {
        case "\t", "\n", "\u{000C}", " ":
            state = .beforeDoctypeName
        case ">":
            reconsumeIn(.beforeDoctypeName)
        default:
            reconsumeIn(.beforeDoctypeName)
        }
    }

    private func processBeforeDoctypeNameState() {
        guard let char = consumeNextChar() else {
            emitDoctype(forceQuirks: true)
            state = .data
            return
        }

        switch char {
        case "\t", "\n", "\u{000C}", " ":
            // Ignore whitespace
            break
        case ">":
            emitDoctype(forceQuirks: true)
            state = .data
        case _ where char.isASCII && char.isUppercase:
            currentDoctypeName = char.lowercased()
            state = .doctypeName
        default:
            currentDoctypeName = String(char)
            state = .doctypeName
        }
    }

    private func processDoctypeNameState() {
        guard let char = consumeNextChar() else {
            emitDoctype(forceQuirks: true)
            state = .data
            return
        }

        switch char {
        case "\t", "\n", "\u{000C}", " ":
            state = .afterDoctypeName
        case ">":
            emitDoctype()
            state = .data
        case _ where char.isASCII && char.isUppercase:
            currentDoctypeName.append(char.lowercased())
        default:
            currentDoctypeName.append(char)
        }
    }

    private func processAfterDoctypeNameState() {
        guard let char = consumeNextChar() else {
            emitDoctype(forceQuirks: true)
            state = .data
            return
        }

        switch char {
        case "\t", "\n", "\u{000C}", " ":
            // Ignore whitespace
            break
        case ">":
            emitDoctype()
            state = .data
        default:
            // Skip PUBLIC/SYSTEM identifiers for now
            while position < input.count && input[position] != ">" {
                position += 1
            }
            if position < input.count {
                position += 1
            }
            emitDoctype()
            state = .data
        }
    }

    // MARK: - Character Reference States

    private func processCharacterReferenceState() {
        temporaryBuffer = "&"

        guard let char = consumeNextChar() else {
            flushTemporaryBuffer()
            state = returnState
            return
        }

        switch char {
        case "#":
            temporaryBuffer.append(char)
            state = .numericCharacterReference
        case _ where char.isLetter || char.isNumber:
            reconsumeIn(.namedCharacterReference)
        default:
            flushTemporaryBuffer()
            reconsumeIn(returnState)
        }
    }

    private func processNamedCharacterReferenceState() {
        // Collect the entity name
        var entityName = ""
        while let char = peek(), char.isLetter || char.isNumber {
            entityName.append(consumeNextChar()!)
        }

        // Check for semicolon
        if peek() == ";" {
            _ = consumeNextChar()
        }

        // Decode the entity
        if let decoded = decodeNamedEntity(entityName) {
            appendToReturnState(decoded)
        } else {
            // Unknown entity - emit as-is
            appendToReturnState("&" + entityName)
        }

        state = returnState
    }

    private func processNumericCharacterReferenceState() {
        characterReferenceCode = 0

        guard let char = consumeNextChar() else {
            flushTemporaryBuffer()
            state = returnState
            return
        }

        switch char {
        case "x", "X":
            temporaryBuffer.append(char)
            state = .hexCharacterReferenceStart
        default:
            reconsumeIn(.decimalCharacterReferenceStart)
        }
    }

    private func processHexCharacterReferenceStartState() {
        guard let char = peek(), char.isHexDigit else {
            flushTemporaryBuffer()
            state = returnState
            return
        }
        state = .hexCharacterReference
    }

    private func processDecimalCharacterReferenceStartState() {
        guard let char = peek(), char.isNumber else {
            flushTemporaryBuffer()
            state = returnState
            return
        }
        state = .decimalCharacterReference
    }

    private func processHexCharacterReferenceState() {
        guard let char = consumeNextChar() else {
            state = .numericCharacterReferenceEnd
            return
        }

        switch char {
        case ";":
            state = .numericCharacterReferenceEnd
        case _ where char.isNumber:
            characterReferenceCode = characterReferenceCode * 16 + UInt32(char.hexDigitValue!)
        case _ where char.isHexDigit:
            characterReferenceCode = characterReferenceCode * 16 + UInt32(char.hexDigitValue!)
        default:
            reconsumeIn(.numericCharacterReferenceEnd)
        }
    }

    private func processDecimalCharacterReferenceState() {
        guard let char = consumeNextChar() else {
            state = .numericCharacterReferenceEnd
            return
        }

        switch char {
        case ";":
            state = .numericCharacterReferenceEnd
        case _ where char.isNumber:
            characterReferenceCode = characterReferenceCode * 10 + UInt32(char.wholeNumberValue!)
        default:
            reconsumeIn(.numericCharacterReferenceEnd)
        }
    }

    private func processNumericCharacterReferenceEndState() {
        // Convert code point to character
        if characterReferenceCode == 0 || characterReferenceCode > 0x10FFFF {
            appendToReturnState("\u{FFFD}")
        } else if let scalar = Unicode.Scalar(characterReferenceCode) {
            appendToReturnState(String(Character(scalar)))
        } else {
            appendToReturnState("\u{FFFD}")
        }

        state = returnState
    }

    // MARK: - Helper Methods

    private func consumeNextChar() -> Character? {
        guard position < input.count else { return nil }
        let char = input[position]
        position += 1
        return char
    }

    private func peek() -> Character? {
        guard position < input.count else { return nil }
        return input[position]
    }

    private func reconsumeIn(_ newState: State) {
        if position > 0 {
            position -= 1
        }
        state = newState
    }

    private func matchNext(_ string: String) -> Bool {
        let chars = Array(string)
        guard position + chars.count <= input.count else { return false }
        for (i, char) in chars.enumerated() {
            if input[position + i] != char {
                return false
            }
        }
        return true
    }

    private func matchNextCaseInsensitive(_ string: String) -> Bool {
        let chars = Array(string.lowercased())
        guard position + chars.count <= input.count else { return false }
        for (i, char) in chars.enumerated() {
            if input[position + i].lowercased() != String(char) {
                return false
            }
        }
        return true
    }

    private func flushCharacterBuffer() {
        if !characterBuffer.isEmpty {
            tokens.append(.character(characterBuffer))
            characterBuffer = ""
        }
    }

    private func flushTemporaryBuffer() {
        appendToReturnState(temporaryBuffer)
        temporaryBuffer = ""
    }

    private func appendToReturnState(_ string: String) {
        switch returnState {
        case .data:
            characterBuffer.append(string)
        case .attributeValueDoubleQuoted, .attributeValueSingleQuoted, .attributeValueUnquoted:
            currentAttributeValue.append(string)
        default:
            characterBuffer.append(string)
        }
    }

    private func emitCurrentTag() {
        if isEndTag {
            tokens.append(.endTag(name: currentTagName))
        } else {
            tokens.append(.startTag(
                name: currentTagName,
                attributes: currentTagAttributes,
                selfClosing: currentTagSelfClosing
            ))
        }
    }

    private func appendCurrentAttribute() {
        if !currentAttributeName.isEmpty {
            currentTagAttributes.append(HTMLAttribute(
                name: currentAttributeName,
                value: currentAttributeValue
            ))
        }
        currentAttributeName = ""
        currentAttributeValue = ""
    }

    private func emitComment() {
        tokens.append(.comment(currentCommentData))
        currentCommentData = ""
    }

    private func emitDoctype(forceQuirks: Bool = false) {
        tokens.append(.doctype(name: currentDoctypeName, publicId: nil, systemId: nil))
        currentDoctypeName = ""
    }

    // MARK: - Entity Decoding

    private func decodeNamedEntity(_ name: String) -> String? {
        let entities: [String: String] = [
            "amp": "&",
            "lt": "<",
            "gt": ">",
            "quot": "\"",
            "apos": "'",
            "nbsp": "\u{00A0}",
            "copy": "\u{00A9}",
            "reg": "\u{00AE}",
            "trade": "\u{2122}",
            "mdash": "\u{2014}",
            "ndash": "\u{2013}",
            "lsquo": "\u{2018}",
            "rsquo": "\u{2019}",
            "ldquo": "\u{201C}",
            "rdquo": "\u{201D}",
            "bull": "\u{2022}",
            "hellip": "\u{2026}",
            "euro": "\u{20AC}",
            "pound": "\u{00A3}",
            "yen": "\u{00A5}",
            "cent": "\u{00A2}",
            "sect": "\u{00A7}",
            "deg": "\u{00B0}",
            "plusmn": "\u{00B1}",
            "times": "\u{00D7}",
            "divide": "\u{00F7}",
            "frac12": "\u{00BD}",
            "frac14": "\u{00BC}",
            "frac34": "\u{00BE}",
        ]
        return entities[name]
    }
}
