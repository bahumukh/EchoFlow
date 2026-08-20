import Foundation

/// Echoflow Text Processor Smoke Tests
/// All 13 baseline test vectors from PRD Section 19.1

@main
struct TextProcessorTests {
    static var passed = 0
    static var failed = 0
    static var testIndex = 0

    static func test(_ name: String, _ block: () -> Bool) {
        testIndex += 1
        if block() {
            passed += 1
            print("  ✓ Test \(testIndex): \(name)")
        } else {
            failed += 1
            print("  ✗ Test \(testIndex): \(name)")
        }
    }

    static func main() {
        let defaultSettings = EchoflowTextProcessor.ProcessingSettings(
            removeFillers: true,
            smartFormatting: true,
            dictionary: [
                EchoflowTextProcessor.DictionaryEntry(spoken: "whisper flow", replacement: "Echoflow", priority: false),
                EchoflowTextProcessor.DictionaryEntry(spoken: "API", replacement: "API", priority: true),
            ],
            snippets: [
                EchoflowTextProcessor.SnippetEntry(trigger: "my email", expansion: "your.email@example.com"),
                EchoflowTextProcessor.SnippetEntry(trigger: "organize my thoughts", expansion: "Please organize the following thoughts into a concise, structured response:"),
            ]
        )

        let addressSettings = EchoflowTextProcessor.ProcessingSettings(
            removeFillers: true,
            smartFormatting: true,
            dictionary: defaultSettings.dictionary,
            snippets: [
                EchoflowTextProcessor.SnippetEntry(trigger: "my address", expansion: "42 Example Road"),
            ]
        )

        print("==> Running Echoflow Text Processor Tests\n")

        // Test 1: Filler removal and formatting
        test("Filler removal and formatting") {
            let result = EchoflowTextProcessor.processText(
                "Um hello comma you know new paragraph this is whisper flow.",
                settings: defaultSettings,
                appBundleID: ""
            )
            if result.text != "Hello,\n\nThis is Echoflow." {
                print("    Expected: Hello,\\n\\nThis is Echoflow.")
                print("    Got:      \(result.text.replacingOccurrences(of: "\n", with: "\\n"))")
            }
            return result.text == "Hello,\n\nThis is Echoflow."
        }

        // Test 2: Backtrack correction
        test("Backtrack correction") {
            let result = EchoflowTextProcessor.processText(
                "Send it on Tuesday. Scratch that, send it on Thursday.",
                settings: defaultSettings,
                appBundleID: ""
            )
            if result.text.lowercased() != "send it on thursday." {
                print("    Expected: send it on thursday.")
                print("    Got:      \(result.text.lowercased())")
            }
            return result.text.lowercased() == "send it on thursday."
        }

        // Test 3: Press-enter text
        test("Press-enter text") {
            let result = EchoflowTextProcessor.processText(
                "Looks good. Press enter.",
                settings: defaultSettings,
                appBundleID: ""
            )
            if result.text != "Looks good." {
                print("    Expected: Looks good.")
                print("    Got:      \(result.text)")
            }
            return result.text == "Looks good."
        }

        // Test 4: Press-enter action
        test("Press-enter action") {
            let result = EchoflowTextProcessor.processText(
                "Looks good. Press enter.",
                settings: defaultSettings,
                appBundleID: ""
            )
            if !result.pressEnter {
                print("    Expected: pressEnter=true")
                print("    Got:      pressEnter=\(result.pressEnter)")
            }
            return result.pressEnter == true
        }

        // Test 5: Snippet expansion
        test("Snippet expansion") {
            let result = EchoflowTextProcessor.processText(
                "Ship it to my address.",
                settings: addressSettings,
                appBundleID: ""
            )
            if result.text != "Ship it to 42 Example Road." {
                print("    Expected: Ship it to 42 Example Road.")
                print("    Got:      \(result.text)")
            }
            return result.text == "Ship it to 42 Example Road."
        }

        // Test 6: Messaging style
        test("Messaging style") {
            let result = EchoflowTextProcessor.processText(
                "Sounds good.",
                settings: defaultSettings,
                appBundleID: "com.tinyspeck.slackmacgap"
            )
            if result.text != "Sounds good" {
                print("    Expected: Sounds good")
                print("    Got:      \(result.text)")
            }
            return result.text == "Sounds good"
        }

        // Test 7: Spacing/question inference
        test("Spacing/question inference") {
            let result = EchoflowTextProcessor.processText(
                "hello ,world!how are you",
                settings: defaultSettings,
                appBundleID: ""
            )
            if result.text != "Hello, world! How are you?" {
                print("    Expected: Hello, world! How are you?")
                print("    Got:      \(result.text)")
            }
            return result.text == "Hello, world! How are you?"
        }

        // Test 8: Question ending
        test("Question ending") {
            let result = EchoflowTextProcessor.processText(
                "can you help me with this",
                settings: defaultSettings,
                appBundleID: ""
            )
            if result.text != "Can you help me with this?" {
                print("    Expected: Can you help me with this?")
                print("    Got:      \(result.text)")
            }
            return result.text == "Can you help me with this?"
        }

        // Test 9: Long run-on
        test("Long run-on") {
            let result = EchoflowTextProcessor.processText(
                "can we improve this formatting I want the spaces and commas to be correct also can you paste the result wherever my cursor is",
                settings: defaultSettings,
                appBundleID: ""
            )
            let expected = "Can we improve this formatting? I want the spaces and commas to be correct. Also, can you paste the result wherever my cursor is?"
            if result.text != expected {
                print("    Expected: \(expected)")
                print("    Got:      \(result.text)")
            }
            return result.text == expected
        }

        // Test 10: Conversational filler
        test("Conversational filler") {
            let result = EchoflowTextProcessor.processText(
                "I mean basically can you fix this",
                settings: defaultSettings,
                appBundleID: ""
            )
            if result.text != "Can you fix this?" {
                print("    Expected: Can you fix this?")
                print("    Got:      \(result.text)")
            }
            return result.text == "Can you fix this?"
        }

        // Test 11: Decimal spacing
        test("Decimal spacing") {
            let result = EchoflowTextProcessor.processText(
                "version 3.7 is ready",
                settings: defaultSettings,
                appBundleID: ""
            )
            if result.text != "Version 3.7 is ready." {
                print("    Expected: Version 3.7 is ready.")
                print("    Got:      \(result.text)")
            }
            return result.text == "Version 3.7 is ready."
        }

        // Test 12: Common grammar
        test("Common grammar") {
            let result = EchoflowTextProcessor.processText(
                "this changes are more better",
                settings: defaultSettings,
                appBundleID: ""
            )
            if result.text != "These changes are better." {
                print("    Expected: These changes are better.")
                print("    Got:      \(result.text)")
            }
            return result.text == "These changes are better."
        }

        // Test 13: Non-speech annotation
        test("Non-speech annotation") {
            let result = EchoflowTextProcessor.processText(
                "[MUSIC PLAYING]",
                settings: defaultSettings,
                appBundleID: ""
            )
            if result.text != "" {
                print("    Expected: (empty)")
                print("    Got:      \(result.text)")
            }
            return result.text == ""
        }

        print("\n==> Results: \(passed) passed, \(failed) failed out of \(testIndex) tests")

        if failed > 0 {
            exit(1)
        } else {
            exit(0)
        }
    }
}
