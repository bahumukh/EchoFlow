import Foundation

/// Deterministic text processor for Echoflow.
/// Applies an ordered pipeline of transformations to raw Whisper transcripts.
/// This class is Foundation-only and has no UI or network dependencies.
class EchoflowTextProcessor {

    /// Result of text processing
    struct ProcessingResult {
        let text: String
        let pressEnter: Bool
    }

    /// Dictionary entry for custom word replacement
    struct DictionaryEntry {
        let spoken: String
        let replacement: String
        let priority: Bool
    }

    /// Snippet entry for phrase expansion
    struct SnippetEntry {
        let trigger: String
        let expansion: String
    }

    /// Settings snapshot used during processing
    struct ProcessingSettings {
        let removeFillers: Bool
        let smartFormatting: Bool
        let dictionary: [DictionaryEntry]
        let snippets: [SnippetEntry]
    }

    /// Bundle identifiers of messaging apps that get final-period removal
    static let messagingBundleIDs: Set<String> = [
        "com.apple.MobileSMS",
        "com.tinyspeck.slackmacgap",
        "net.whatsapp.WhatsApp",
        "com.hnc.Discord",
        "ru.keepcoder.Telegram",
        "org.whispersystems.signal-desktop",
        "com.microsoft.teams2",
        "com.microsoft.teams"
    ]

    /// Process raw transcript text through the full pipeline.
    /// - Parameters:
    ///   - rawText: The raw transcript from whisper-cli
    ///   - settings: Processing settings snapshot
    ///   - appBundleID: Bundle identifier of the frontmost app at recording start
    /// - Returns: ProcessingResult with cleaned text and pressEnter flag
    static func processText(_ rawText: String, settings: ProcessingSettings, appBundleID: String) -> ProcessingResult {
        var text = rawText

        // 1. Remove non-speech annotations
        text = removeNonSpeechAnnotations(text)

        // 2. Trim
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 3. Backtrack commands
        text = applyBacktrackCommands(text)

        // 4. Detect and remove trailing "press enter"
        var pressEnter = false
        (text, pressEnter) = detectPressEnter(text)

        // 5. Spoken formatting commands + ordinal list
        if settings.smartFormatting {
            text = applySpokenFormatting(text)
            text = applyOrdinalList(text)
        }

        // 6. Filler removal
        if settings.removeFillers {
            text = removeFillers(text)
        }

        // 7. User dictionary
        text = applyDictionary(text, entries: settings.dictionary)

        // 8. User snippets
        text = applySnippets(text, entries: settings.snippets)

        // 9. Built-in corrections
        text = applyBuiltInCorrections(text)

        // 10. Normalize
        text = normalize(text)

        // 11. Smart formatting: split, commas, punctuation, capitalization
        if settings.smartFormatting && !text.isEmpty {
            text = splitRunOnSentences(text)
            text = normalize(text)
            text = inferCommas(text)
            text = normalize(text)
            text = addTerminalPunctuation(text)
            text = capitalizeSentences(text)
            text = normalize(text)
        }

        // 12. Messaging app final-period removal
        if messagingBundleIDs.contains(appBundleID) {
            text = removeMessagingFinalPeriod(text)
        }

        return ProcessingResult(text: text, pressEnter: pressEnter)
    }

    // MARK: - Step 1: Non-speech annotations

    static func removeNonSpeechAnnotations(_ text: String) -> String {
        var result = text

        // Bracketed forms: [blank_audio], [silence], [music playing], [applause], [laughter], [inaudible]
        // May consume additional characters until ], allowing variants
        let bracketedPattern = "\\[\\s*(?:blank_audio|silence|music\\s*playing|applause|laughter|inaudible)[^\\]]*\\]"
        if let regex = try? NSRegularExpression(pattern: bracketedPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }

        // Parenthesized forms
        let parenPattern = "\\(\\s*(?:muffled\\s+speaking|speaking\\s+in\\s+foreign\\s+language|music\\s*playing|inaudible|silence)\\s*\\)"
        if let regex = try? NSRegularExpression(pattern: parenPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }

        return result
    }

    // MARK: - Step 3: Backtrack commands

    static func applyBacktrackCommands(_ text: String) -> String {
        var result = text
        let triggers = ["scratch that", "forget that", "start over"]

        for trigger in triggers {
            let lower = result.lowercased()
            if let range = lower.range(of: trigger, options: .backwards) {
                let afterTrigger = result[range.upperBound...]
                // Trim leading whitespace, newline, comma, period, semicolon, colon, hyphen
                let trimChars = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",.;:-"))
                result = String(afterTrigger).trimmingLeadingCharacters(in: trimChars)
            }
        }

        return result
    }

    // MARK: - Step 4: Press Enter detection

    static func detectPressEnter(_ text: String) -> (String, Bool) {
        // Match "press enter" at end, optionally followed by . ! ?
        let pattern = "(?<![\\p{L}\\p{N}])press\\s+enter[.!?]?\\s*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return (text, false)
        }

        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, range: range) {
            let matchRange = Range(match.range, in: text)!
            var cleaned = String(text[text.startIndex..<matchRange.lowerBound])
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            return (cleaned, true)
        }

        return (text, false)
    }

    // MARK: - Step 5: Spoken formatting commands

    static func applySpokenFormatting(_ text: String) -> String {
        var result = text

        let replacements: [(String, String)] = [
            ("new paragraph", "\n\n"),
            ("new line", "\n"),
            ("next line", "\n"),
            ("line break", "\n"),
            ("full stop", "."),
            ("question mark", "?"),
            ("exclamation mark", "!"),
            ("exclamation point", "!"),
            ("comma", ","),
            ("colon", ":"),
            ("semicolon", ";"),
            ("open quote", "\""),
            ("close quote", "\""),
        ]

        for (spoken, output) in replacements {
            result = replaceWholePhrase(in: result, phrase: spoken, with: output)
        }

        return result
    }

    // MARK: - Step 5b: Ordinal list conversion

    static func applyOrdinalList(_ text: String) -> String {
        let lower = text.lowercased()
        guard lower.contains("first") && lower.contains("second") else {
            return text
        }

        var result = text

        // Work from fifth backward to first
        let ordinals: [(String, String)] = [
            ("fifth", "\n5. "),
            ("fourth", "\n4. "),
            ("third", "\n3. "),
            ("second", "\n2. "),
            ("first", "\n1. "),
        ]

        for (marker, replacement) in ordinals {
            // Permit optional comma, colon, and following whitespace after the marker
            let pattern = "(?<![\\p{L}\\p{N}])\(marker)(?![\\p{L}\\p{N}])[,:]?\\s*"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: replacement)
            }
        }

        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }

    // MARK: - Step 6: Filler removal

    static func removeFillers(_ text: String) -> String {
        var result = text

        // Filler patterns with optional repeated last char
        let fillerPatterns: [String] = [
            "u[mM]m*",        // um, umm, ummm...
            "u[hH]h*",        // uh, uhh, uhhh...
            "e[rR]mm*",       // erm, ermm...
            "you know",
            "i mean",
            "kind of",
            "sort of",
            "basically",
        ]

        for filler in fillerPatterns {
            // Do not match inside a larger Unicode word. Remove optional following comma and whitespace.
            let pattern = "(?<![\\p{L}\\p{N}])\(filler)(?![\\p{L}\\p{N}]),?[\\t ]*"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
            }
        }

        return result
    }

    // MARK: - Step 7: Dictionary replacement

    static func applyDictionary(_ text: String, entries: [DictionaryEntry]) -> String {
        // Sort: priority=true first, then by descending spoken length
        let sorted = entries.sorted { a, b in
            if a.priority != b.priority {
                return a.priority && !b.priority
            }
            return a.spoken.count > b.spoken.count
        }

        var result = text
        for entry in sorted {
            guard !entry.spoken.isEmpty else { continue }
            result = replaceWholePhrase(in: result, phrase: entry.spoken, with: entry.replacement)
        }
        return result
    }

    // MARK: - Step 8: Snippet expansion

    static func applySnippets(_ text: String, entries: [SnippetEntry]) -> String {
        // Sort by descending trigger length
        let sorted = entries.sorted { $0.trigger.count > $1.trigger.count }

        var result = text
        for entry in sorted {
            guard !entry.trigger.isEmpty else { continue }
            result = replaceWholePhrase(in: result, phrase: entry.trigger, with: entry.expansion)
        }
        return result
    }

    // MARK: - Step 9: Built-in corrections

    static func applyBuiltInCorrections(_ text: String) -> String {
        var result = text

        // Whole phrase replacements
        result = replaceWholePhrase(in: result, phrase: "option plus space", with: "Option + Space")

        // control-v, control v, controlv → Command-V
        let controlVPattern = "(?<![\\p{L}\\p{N}])control[\\s-]?v(?![\\p{L}\\p{N}])"
        if let regex = try? NSRegularExpression(pattern: controlVPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "Command-V")
        }

        result = replaceWholePhrase(in: result, phrase: "local flow", with: "Echoflow")

        // "this changes/things/settings/files/options/features/permissions/questions" → "these <noun>"
        let thisPattern = "(?<![\\p{L}\\p{N}])this\\s+(changes|things|settings|files|options|features|permissions|questions)(?![\\p{L}\\p{N}])"
        if let regex = try? NSRegularExpression(pattern: thisPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "these $1")
        }

        // "these is" → "these are"
        result = replaceWholePhrase(in: result, phrase: "these is", with: "these are")
        // "these was" → "these were"
        result = replaceWholePhrase(in: result, phrase: "these was", with: "these were")
        // "more better" → "better"
        result = replaceWholePhrase(in: result, phrase: "more better", with: "better")
        // "stuffs" → "things"
        result = replaceWholePhrase(in: result, phrase: "stuffs", with: "things")

        return result
    }

    // MARK: - Step 10: Normalization

    static func normalize(_ text: String) -> String {
        var result = text

        // Collapse horizontal spaces/tabs to one space
        result = regReplace(result, pattern: "[\\t ]+", with: " ")

        // Remove spaces immediately around each newline
        result = regReplace(result, pattern: " *\\n *", with: "\n")

        // Collapse three or more newlines to two
        result = regReplace(result, pattern: "\\n{3,}", with: "\n\n")

        // Remove whitespace before , . ; : ! ?
        result = regReplace(result, pattern: "\\s+([,\\.;:!?])", with: "$1")

        // Insert space after ; : ! ? when followed by letter/number
        result = regReplace(result, pattern: "([;:!?])([\\p{L}\\p{N}])", with: "$1 $2")

        // Insert space after . or , when followed by letter/number,
        // EXCEPT when preceded by a number (preserves "3.7", "1,000")
        result = regReplace(result, pattern: "(?<![\\p{N}])([.,])([\\p{L}\\p{N}])", with: "$1 $2")

        // Remove whitespace immediately after (
        result = regReplace(result, pattern: "\\(\\s+", with: "(")

        // Remove whitespace immediately before )
        result = regReplace(result, pattern: "\\s+\\)", with: ")")

        // Collapse repeated commas to one
        result = regReplace(result, pattern: ",{2,}", with: ",")

        // Collapse repeated exclamation marks to one
        result = regReplace(result, pattern: "!{2,}", with: "!")

        // Collapse repeated question marks to one
        result = regReplace(result, pattern: "\\?{2,}", with: "?")

        // Trim outer whitespace/newlines
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    // MARK: - Step 10.13: Word counting

    static func countWords(_ text: String) -> Int {
        // Count sequences of Unicode letters/numbers with optional apostrophe-delimited letter suffix
        let pattern = "[\\p{L}\\p{N}]+(?:'[\\p{L}]+)?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    // MARK: - Step 10.14: Question inference

    static func isLikelyQuestion(_ text: String) -> Bool {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Remove initial discourse word plus comma/space
        let discourseWords = ["also", "so", "then", "well", "please"]
        for word in discourseWords {
            let pattern = "^\(word)[,\\s]+"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
            }
        }

        let questionStarters = [
            "who", "what", "when", "where", "why", "how", "which", "whose", "whom",
            "can", "could", "would", "will", "shall", "should",
            "do", "does", "did",
            "is", "are", "am", "was", "were",
            "have", "has", "had",
            "may", "might", "must"
        ]

        for starter in questionStarters {
            let pattern = "^\(starter)(?:\\s|$)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil {
                return true
            }
        }

        return false
    }

    // MARK: - Step 10.15: Run-on sentence splitting

    static func splitRunOnSentences(_ text: String) -> String {
        let wordCount = countWords(text)
        guard wordCount >= 14 else { return text }

        // Don't split if already has sentence-ending punctuation
        if text.contains(".") || text.contains("!") || text.contains("?") {
            return text
        }

        // Candidate boundary patterns
        let boundaryPatterns: [String] = [
            "also", "however", "but rather",
            "I want", "I need", "I feel", "I think", "I don't",
            "we need", "we should", "it should",
            "can you", "could you", "would you", "will you",
            "do you", "does it", "did you",
            "what is", "what are", "what was", "what were",
            "why did", "why do", "why does", "why is", "why are",
            "how can", "how could", "how do", "how does", "how is", "how are",
            "where should", "where is", "where are", "where do",
            "when will", "when do", "when does", "when is",
            "who is", "who are", "who was",
            "which is", "which are",
            "another thing", "the next thing",
            "please remove", "please keep", "please delete",
            "remove", "keep", "delete",
        ]

        // Find all candidate boundary positions
        struct Boundary {
            let position: String.Index
            let length: Int
        }

        var candidates: [Boundary] = []

        for pattern in boundaryPatterns {
            var searchStart = text.startIndex
            while let range = text.range(of: pattern, options: .caseInsensitive, range: searchStart..<text.endIndex) {
                // Check it's not at the beginning
                if range.lowerBound != text.startIndex {
                    // Check word boundary before
                    let charBefore = text[text.index(before: range.lowerBound)]
                    if !charBefore.isLetter && !charBefore.isNumber {
                        candidates.append(Boundary(position: range.lowerBound, length: pattern.count))
                    }
                }
                searchStart = text.index(after: range.lowerBound)
                if searchStart >= text.endIndex { break }
            }
        }

        // Sort by position
        candidates.sort { text.distance(from: text.startIndex, to: $0.position) < text.distance(from: text.startIndex, to: $1.position) }

        // Accept candidates that meet word-count constraints
        var accepted: [String.Index] = []
        var lastBoundary = text.startIndex

        for candidate in candidates {
            guard candidate.position != text.startIndex else { continue }

            let portionBefore = String(text[lastBoundary..<candidate.position])
            let portionAfter = String(text[candidate.position...])

            let wordsBefore = countWords(portionBefore)
            let wordsAfter = countWords(portionAfter)

            if wordsBefore >= 5 && wordsAfter >= 3 {
                accepted.append(candidate.position)
                lastBoundary = candidate.position
            }
        }

        // Insert boundaries from end backward
        var result = text
        for (idx, boundary) in accepted.reversed().enumerated() {
            // Find the preceding boundary (the next one in the reversed-reversed order)
            // Since we're iterating reversed, the "previous" accepted boundary is at idx-1 in reversed
            // = accepted[accepted.count - idx] in original order
            let prevBoundaryIdx = accepted.count - 1 - idx - 1
            let segmentStart: String.Index
            if prevBoundaryIdx >= 0 {
                segmentStart = accepted[prevBoundaryIdx]
            } else {
                segmentStart = result.startIndex
            }
            let portionBefore = String(result[segmentStart..<boundary]).trimmingCharacters(in: .whitespaces)
            let separator = isLikelyQuestion(portionBefore) ? "? " : ". "

            // Remove any trailing whitespace/comma at boundary
            var insertionPoint = boundary
            while insertionPoint > result.startIndex {
                let prevIdx = result.index(before: insertionPoint)
                let c = result[prevIdx]
                if c == " " || c == "," {
                    insertionPoint = prevIdx
                } else {
                    break
                }
            }

            result = String(result[result.startIndex..<insertionPoint]) + separator + String(result[boundary...])
        }

        return result
    }

    // MARK: - Step 10.16: Inferred commas

    static func inferCommas(_ text: String) -> String {
        var result = text

        // 1. Insert comma after sentence/line-initial discourse words when missing
        let initialWords = [
            "however", "therefore", "additionally", "also", "meanwhile", "instead", "finally",
            "first", "second", "third",
            "yes", "no", "well",
        ]
        for word in initialWords {
            // Match at start of string, after newline, or after sentence-ending punctuation + space
            let pattern = "((?:^|\\n|[.!?]\\s)\(word))\\s+(?!,)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1, ")
            }
        }

        // Multi-word initial phrases
        let initialPhrases = ["for example", "in fact", "by the way"]
        for phrase in initialPhrases {
            let pattern = "((?:^|\\n|[.!?]\\s)\(phrase))\\s+(?!,)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1, ")
            }
        }

        // 2. Comma before "but" or "yet" when followed by pronoun/demonstrative subject
        let subjects = "I|you|we|they|he|she|it|this|that|these|those"
        let butYetPattern = "(?<!,)\\s+(but|yet)\\s+(\(subjects))(?:\\s|$)"
        if let regex = try? NSRegularExpression(pattern: butYetPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: ", $1 $2 ")
        }

        // 3. " and then " → ", then "
        result = result.replacingOccurrences(of: " and then ", with: ", then ", options: .caseInsensitive)

        // 4. Comma before "so" when followed by a subject
        let soPattern = "(?<!,)\\s+so\\s+(\(subjects))(?:\\s|$)"
        if let regex = try? NSRegularExpression(pattern: soPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: ", so $1 ")
        }

        return result
    }

    // MARK: - Step 10.17: Terminal punctuation

    static func addTerminalPunctuation(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let processed = lines.map { line -> String in
            // Preserve blank lines
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return line }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check if already ends with punctuation (including comma per PRD)
            if let last = trimmed.last, ".,!?:;\"".contains(last) {
                return line
            }

            // Examine text after the last sentence-ending punctuation
            let textToCheck: String
            if let lastPunctIdx = trimmed.lastIndex(where: { ".!?".contains($0) }) {
                textToCheck = String(trimmed[trimmed.index(after: lastPunctIdx)...])
            } else {
                textToCheck = trimmed
            }

            let punct = isLikelyQuestion(textToCheck) ? "?" : "."
            return line.trimmingTrailingWhitespace() + punct
        }
        return processed.joined(separator: "\n")
    }

    // MARK: - Step 10.18: Sentence capitalization

    static func capitalizeSentences(_ text: String) -> String {
        var chars = Array(text)
        var pendingCapitalization = true

        var i = 0
        while i < chars.count {
            let c = chars[i]

            if pendingCapitalization {
                if c.isLetter && c.isLowercase {
                    chars[i] = Character(c.uppercased())
                    pendingCapitalization = false
                } else if c.isLetter || c.isNumber {
                    pendingCapitalization = false
                }
            }

            // Capitalize after newline
            if c == "\n" {
                pendingCapitalization = true
            }

            // Capitalize after . ! ? only when followed by whitespace/newline or is final character
            if ".!?".contains(c) {
                if i + 1 >= chars.count {
                    pendingCapitalization = true
                } else {
                    let next = chars[i + 1]
                    if next == " " || next == "\n" || next == "\t" {
                        pendingCapitalization = true
                    }
                }
            }

            i += 1
        }

        return String(chars)
    }

    // MARK: - Step 12: Messaging app final-period removal

    static func removeMessagingFinalPeriod(_ text: String) -> String {
        guard text.hasSuffix(".") else { return text }

        // Count sentence terminators by splitting on . ! ?
        let terminators = text.filter { ".!?".contains($0) }
        // If no more than 2 terminated sentences and ends in period, remove it
        if terminators.count <= 2 {
            return String(text.dropLast())
        }
        return text
    }

    // MARK: - Utility: Whole-phrase replacement

    /// Replace whole phrases using Unicode word boundaries.
    /// Matches are case-insensitive and must not be inside a larger alphanumeric word.
    static func replaceWholePhrase(in text: String, phrase: String, with replacement: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let pattern = "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return text
        }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: replacement)
    }

    // MARK: - Utility: Regex replace

    static func regReplace(_ text: String, pattern: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }
}

// MARK: - String extensions

extension String {
    func trimmingLeadingCharacters(in characterSet: CharacterSet) -> String {
        var idx = startIndex
        while idx < endIndex {
            let scalar = unicodeScalars[unicodeScalars.index(unicodeScalars.startIndex, offsetBy: distance(from: startIndex, to: idx))]
            if !characterSet.contains(scalar) {
                break
            }
            idx = index(after: idx)
        }
        return String(self[idx...])
    }

    func trimmingTrailingWhitespace() -> String {
        var idx = endIndex
        while idx > startIndex {
            let prevIdx = index(before: idx)
            if self[prevIdx] != " " && self[prevIdx] != "\t" {
                break
            }
            idx = prevIdx
        }
        return String(self[startIndex..<idx])
    }
}
