using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace Echoflow.Services
{
    /// <summary>
    /// Full 12-step text processing pipeline ported from macOS EchoflowTextProcessor.swift.
    /// Applies deterministic transformations to raw Whisper transcripts.
    /// </summary>
    public static class TextProcessorService
    {
        public class ProcessingResult
        {
            public string Text { get; set; } = "";
            public bool PressEnter { get; set; } = false;
        }

        public class ProcessingSettings
        {
            public bool RemoveFillers { get; set; } = true;
            public bool SmartFormatting { get; set; } = true;
            public List<DictionaryEntry> Dictionary { get; set; } = new();
            public List<SnippetEntry> Snippets { get; set; } = new();
        }

        // Messaging app executable names (Windows equivalent of macOS bundle IDs)
        private static readonly HashSet<string> MessagingApps = new(StringComparer.OrdinalIgnoreCase)
        {
            "slack", "teams", "discord", "telegram", "signal", "whatsapp"
        };

        /// <summary>
        /// Process raw transcript text through the full pipeline.
        /// </summary>
        public static ProcessingResult ProcessText(string rawText, ProcessingSettings settings, string appName = "")
        {
            string text = rawText;

            // 1. Remove non-speech annotations
            text = RemoveNonSpeechAnnotations(text);

            // 2. Trim
            text = text.Trim();

            // 3. Backtrack commands
            text = ApplyBacktrackCommands(text);

            // 4. Detect and remove trailing "press enter"
            var (pressEnterText, pressEnter) = DetectPressEnter(text);
            text = pressEnterText;

            // 5. Spoken formatting commands + ordinal list
            if (settings.SmartFormatting)
            {
                text = ApplySpokenFormatting(text);
                text = ApplyOrdinalList(text);
            }

            // 6. Filler removal
            if (settings.RemoveFillers)
            {
                text = RemoveFillers(text);
            }

            // 7. User dictionary
            text = ApplyDictionary(text, settings.Dictionary);

            // 8. User snippets
            text = ApplySnippets(text, settings.Snippets);

            // 9. Built-in corrections
            text = ApplyBuiltInCorrections(text);

            // 10. Normalize
            text = Normalize(text);

            // 11. Smart formatting: split, commas, punctuation, capitalization
            if (settings.SmartFormatting && !string.IsNullOrEmpty(text))
            {
                text = SplitRunOnSentences(text);
                text = Normalize(text);
                text = InferCommas(text);
                text = Normalize(text);
                text = AddTerminalPunctuation(text);
                text = CapitalizeSentences(text);
                text = Normalize(text);
            }

            // 12. Messaging app final-period removal
            string lowerApp = appName.ToLowerInvariant();
            if (MessagingApps.Any(app => lowerApp.Contains(app)))
            {
                text = RemoveMessagingFinalPeriod(text);
            }

            return new ProcessingResult { Text = text, PressEnter = pressEnter };
        }

        // --- Step 1: Non-speech annotations ---

        public static string RemoveNonSpeechAnnotations(string text)
        {
            string result = text;

            // Bracketed forms: [blank_audio], [silence], [music playing], etc.
            result = Regex.Replace(result,
                @"\[\s*(?:blank_audio|silence|music\s*playing|applause|laughter|inaudible)[^\]]*\]",
                "", RegexOptions.IgnoreCase);

            // Parenthesized forms
            result = Regex.Replace(result,
                @"\(\s*(?:muffled\s+speaking|speaking\s+in\s+foreign\s+language|music\s*playing|inaudible|silence)\s*\)",
                "", RegexOptions.IgnoreCase);

            return result;
        }

        // --- Step 3: Backtrack commands ---

        public static string ApplyBacktrackCommands(string text)
        {
            string result = text;
            string[] triggers = { "scratch that", "forget that", "start over" };

            foreach (var trigger in triggers)
            {
                int idx = result.ToLowerInvariant().LastIndexOf(trigger, StringComparison.Ordinal);
                if (idx >= 0)
                {
                    string afterTrigger = result.Substring(idx + trigger.Length);
                    result = afterTrigger.TrimStart(' ', '\t', '\n', '\r', ',', '.', ';', ':', '-');
                }
            }

            return result;
        }

        // --- Step 4: Press Enter detection ---

        public static (string, bool) DetectPressEnter(string text)
        {
            var match = Regex.Match(text, @"(?<![\p{L}\p{N}])press\s+enter[.!?]?\s*$", RegexOptions.IgnoreCase);
            if (match.Success)
            {
                string cleaned = text.Substring(0, match.Index).Trim();
                return (cleaned, true);
            }
            return (text, false);
        }

        // --- Step 5: Spoken formatting commands ---

        public static string ApplySpokenFormatting(string text)
        {
            string result = text;

            var replacements = new (string spoken, string output)[]
            {
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
            };

            foreach (var (spoken, output) in replacements)
            {
                result = ReplaceWholePhrase(result, spoken, output);
            }

            return result;
        }

        // --- Step 5b: Ordinal list conversion ---

        public static string ApplyOrdinalList(string text)
        {
            string lower = text.ToLowerInvariant();
            if (!lower.Contains("first") || !lower.Contains("second"))
                return text;

            string result = text;

            var ordinals = new (string marker, string replacement)[]
            {
                ("fifth", "\n5. "),
                ("fourth", "\n4. "),
                ("third", "\n3. "),
                ("second", "\n2. "),
                ("first", "\n1. "),
            };

            foreach (var (marker, replacement) in ordinals)
            {
                string pattern = $@"(?<![\p{{L}}\p{{N}}]){Regex.Escape(marker)}(?![\p{{L}}\p{{N}}])[,:]?\s*";
                result = Regex.Replace(result, pattern, replacement, RegexOptions.IgnoreCase);
            }

            return result.Trim();
        }

        // --- Step 6: Filler removal ---

        public static string RemoveFillers(string text)
        {
            string result = text;

            string[] fillerPatterns =
            {
                @"u[mM]m*",
                @"u[hH]h*",
                @"e[rR]mm*",
                "you know",
                "i mean",
                "kind of",
                "sort of",
                "basically",
            };

            foreach (var filler in fillerPatterns)
            {
                string pattern = $@"(?<![\p{{L}}\p{{N}}]){filler}(?![\p{{L}}\p{{N}}]),?[\t ]*";
                result = Regex.Replace(result, pattern, "", RegexOptions.IgnoreCase);
            }

            return result;
        }

        // --- Step 7: Dictionary replacement ---

        public static string ApplyDictionary(string text, List<DictionaryEntry> entries)
        {
            var sorted = entries
                .OrderByDescending(e => e.Priority)
                .ThenByDescending(e => e.Spoken.Length)
                .ToList();

            string result = text;
            foreach (var entry in sorted)
            {
                if (!string.IsNullOrEmpty(entry.Spoken))
                    result = ReplaceWholePhrase(result, entry.Spoken, entry.Replacement);
            }
            return result;
        }

        // --- Step 8: Snippet expansion ---

        public static string ApplySnippets(string text, List<SnippetEntry> entries)
        {
            var sorted = entries.OrderByDescending(e => e.Trigger.Length).ToList();

            string result = text;
            foreach (var entry in sorted)
            {
                if (!string.IsNullOrEmpty(entry.Trigger))
                    result = ReplaceWholePhrase(result, entry.Trigger, entry.Expansion);
            }
            return result;
        }

        // --- Step 9: Built-in corrections ---

        public static string ApplyBuiltInCorrections(string text)
        {
            string result = text;

            result = ReplaceWholePhrase(result, "option plus space", "Option + Space");
            result = Regex.Replace(result, @"(?<![\p{L}\p{N}])control[\s-]?v(?![\p{L}\p{N}])", "Ctrl+V", RegexOptions.IgnoreCase);
            result = ReplaceWholePhrase(result, "local flow", "Echoflow");
            result = ReplaceWholePhrase(result, "echo flow", "Echoflow");

            // "this changes/things/..." → "these <noun>"
            result = Regex.Replace(result,
                @"(?<![\p{L}\p{N}])this\s+(changes|things|settings|files|options|features|permissions|questions)(?![\p{L}\p{N}])",
                "these $1", RegexOptions.IgnoreCase);

            result = ReplaceWholePhrase(result, "these is", "these are");
            result = ReplaceWholePhrase(result, "these was", "these were");
            result = ReplaceWholePhrase(result, "more better", "better");
            result = ReplaceWholePhrase(result, "stuffs", "things");

            return result;
        }

        // --- Step 10: Normalization ---

        public static string Normalize(string text)
        {
            string result = text;

            // Collapse horizontal spaces/tabs to one space
            result = Regex.Replace(result, @"[\t ]+", " ");
            // Remove spaces around newlines
            result = Regex.Replace(result, @" *\n *", "\n");
            // Collapse 3+ newlines to 2
            result = Regex.Replace(result, @"\n{3,}", "\n\n");
            // Remove whitespace before , . ; : ! ?
            result = Regex.Replace(result, @"\s+([,.;:!?])", "$1");
            // Insert space after ; : ! ? when followed by letter/number
            result = Regex.Replace(result, @"([;:!?])([\p{L}\p{N}])", "$1 $2");
            // Insert space after . or , when followed by letter/number (except after digit)
            result = Regex.Replace(result, @"(?<![\p{N}])([.,])([\p{L}\p{N}])", "$1 $2");
            // Remove whitespace after (
            result = Regex.Replace(result, @"\(\s+", "(");
            // Remove whitespace before )
            result = Regex.Replace(result, @"\s+\)", ")");
            // Collapse repeated punctuation
            result = Regex.Replace(result, @",{2,}", ",");
            result = Regex.Replace(result, @"!{2,}", "!");
            result = Regex.Replace(result, @"\?{2,}", "?");
            // Trim
            result = result.Trim();

            return result;
        }

        // --- Step 10.13: Word counting ---

        public static int CountWords(string text)
        {
            return Regex.Matches(text, @"[\p{L}\p{N}]+(?:'[\p{L}]+)?").Count;
        }

        // --- Step 10.14: Question inference ---

        public static bool IsLikelyQuestion(string text)
        {
            string s = text.Trim().ToLowerInvariant();

            // Remove initial discourse word
            string[] discourseWords = { "also", "so", "then", "well", "please" };
            foreach (var word in discourseWords)
            {
                s = Regex.Replace(s, $@"^{Regex.Escape(word)}[,\s]+", "", RegexOptions.IgnoreCase);
            }

            string[] starters =
            {
                "who", "what", "when", "where", "why", "how", "which", "whose", "whom",
                "can", "could", "would", "will", "shall", "should",
                "do", "does", "did",
                "is", "are", "am", "was", "were",
                "have", "has", "had",
                "may", "might", "must"
            };

            foreach (var starter in starters)
            {
                if (Regex.IsMatch(s, $@"^{Regex.Escape(starter)}(?:\s|$)", RegexOptions.IgnoreCase))
                    return true;
            }

            return false;
        }

        // --- Step 10.15: Run-on sentence splitting ---

        public static string SplitRunOnSentences(string text)
        {
            int wordCount = CountWords(text);
            if (wordCount < 14) return text;

            if (text.Contains('.') || text.Contains('!') || text.Contains('?'))
                return text;

            string[] boundaryPatterns =
            {
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
            };

            var candidates = new List<(int position, int length)>();
            string lowerText = text.ToLowerInvariant();

            foreach (var pattern in boundaryPatterns)
            {
                int searchStart = 0;
                while (true)
                {
                    int idx = lowerText.IndexOf(pattern, searchStart, StringComparison.Ordinal);
                    if (idx < 0) break;

                    if (idx > 0)
                    {
                        char charBefore = text[idx - 1];
                        if (!char.IsLetterOrDigit(charBefore))
                        {
                            candidates.Add((idx, pattern.Length));
                        }
                    }
                    searchStart = idx + 1;
                    if (searchStart >= text.Length) break;
                }
            }

            candidates = candidates.OrderBy(c => c.position).ToList();

            var accepted = new List<int>();
            int lastBoundary = 0;

            foreach (var (position, length) in candidates)
            {
                if (position == 0) continue;

                string portionBefore = text.Substring(lastBoundary, position - lastBoundary);
                string portionAfter = text.Substring(position);

                int wordsBefore = CountWords(portionBefore);
                int wordsAfter = CountWords(portionAfter);

                if (wordsBefore >= 5 && wordsAfter >= 3)
                {
                    accepted.Add(position);
                    lastBoundary = position;
                }
            }

            // Insert boundaries from end backward
            string result = text;
            for (int i = accepted.Count - 1; i >= 0; i--)
            {
                int boundary = accepted[i];
                int segmentStart = i > 0 ? accepted[i - 1] : 0;
                string portionBefore = result.Substring(segmentStart, boundary - segmentStart).Trim();
                string separator = IsLikelyQuestion(portionBefore) ? "? " : ". ";

                // Remove trailing whitespace/comma at boundary
                int insertionPoint = boundary;
                while (insertionPoint > 0)
                {
                    char c = result[insertionPoint - 1];
                    if (c == ' ' || c == ',')
                        insertionPoint--;
                    else
                        break;
                }

                result = result.Substring(0, insertionPoint) + separator + result.Substring(boundary);
            }

            return result;
        }

        // --- Step 10.16: Inferred commas ---

        public static string InferCommas(string text)
        {
            string result = text;

            // Comma after sentence-initial discourse words
            string[] initialWords =
            {
                "however", "therefore", "additionally", "also", "meanwhile", "instead", "finally",
                "first", "second", "third", "yes", "no", "well"
            };

            foreach (var word in initialWords)
            {
                string pattern = $@"((?:^|\n|[.!?]\s){Regex.Escape(word)})\s+(?!,)";
                result = Regex.Replace(result, pattern, "$1, ", RegexOptions.IgnoreCase);
            }

            // Multi-word initial phrases
            string[] initialPhrases = { "for example", "in fact", "by the way" };
            foreach (var phrase in initialPhrases)
            {
                string pattern = $@"((?:^|\n|[.!?]\s){Regex.Escape(phrase)})\s+(?!,)";
                result = Regex.Replace(result, pattern, "$1, ", RegexOptions.IgnoreCase);
            }

            // Comma before "but" or "yet" when followed by pronoun/demonstrative
            string subjects = "I|you|we|they|he|she|it|this|that|these|those";
            result = Regex.Replace(result,
                $@"(?<!,)\s+(but|yet)\s+({subjects})(?:\s|$)",
                ", $1 $2 ", RegexOptions.IgnoreCase);

            // " and then " → ", then "
            result = Regex.Replace(result, @" and then ", ", then ", RegexOptions.IgnoreCase);

            // Comma before "so" when followed by a subject
            result = Regex.Replace(result,
                $@"(?<!,)\s+so\s+({subjects})(?:\s|$)",
                ", so $1 ", RegexOptions.IgnoreCase);

            return result;
        }

        // --- Step 10.17: Terminal punctuation ---

        public static string AddTerminalPunctuation(string text)
        {
            string[] lines = text.Split('\n');
            for (int i = 0; i < lines.Length; i++)
            {
                string trimmed = lines[i].Trim();
                if (string.IsNullOrEmpty(trimmed)) continue;

                char last = trimmed[trimmed.Length - 1];
                if (".,!?:;\"".Contains(last)) continue;

                // Examine text after last sentence-ending punctuation
                string textToCheck;
                int lastPunctIdx = trimmed.LastIndexOfAny(new[] { '.', '!', '?' });
                if (lastPunctIdx >= 0)
                    textToCheck = trimmed.Substring(lastPunctIdx + 1);
                else
                    textToCheck = trimmed;

                string punct = IsLikelyQuestion(textToCheck) ? "?" : ".";
                lines[i] = lines[i].TrimEnd() + punct;
            }
            return string.Join("\n", lines);
        }

        // --- Step 10.18: Sentence capitalization ---

        public static string CapitalizeSentences(string text)
        {
            char[] chars = text.ToCharArray();
            bool pendingCapitalization = true;

            for (int i = 0; i < chars.Length; i++)
            {
                char c = chars[i];

                if (pendingCapitalization)
                {
                    if (char.IsLetter(c) && char.IsLower(c))
                    {
                        chars[i] = char.ToUpper(c);
                        pendingCapitalization = false;
                    }
                    else if (char.IsLetterOrDigit(c))
                    {
                        pendingCapitalization = false;
                    }
                }

                if (c == '\n')
                    pendingCapitalization = true;

                if (".!?".Contains(c))
                {
                    if (i + 1 >= chars.Length)
                        pendingCapitalization = true;
                    else
                    {
                        char next = chars[i + 1];
                        if (next == ' ' || next == '\n' || next == '\t')
                            pendingCapitalization = true;
                    }
                }
            }

            return new string(chars);
        }

        // --- Step 12: Messaging app final-period removal ---

        public static string RemoveMessagingFinalPeriod(string text)
        {
            if (!text.EndsWith('.')) return text;

            int terminators = text.Count(c => ".!?".Contains(c));
            if (terminators <= 2)
                return text.Substring(0, text.Length - 1);

            return text;
        }

        // --- Utility: Whole-phrase replacement ---

        public static string ReplaceWholePhrase(string text, string phrase, string replacement)
        {
            string escaped = Regex.Escape(phrase);
            string pattern = $@"(?<![\p{{L}}\p{{N}}]){escaped}(?![\p{{L}}\p{{N}}])";
            return Regex.Replace(text, pattern, replacement, RegexOptions.IgnoreCase);
        }
    }
}
