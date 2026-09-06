import Foundation

struct GrammarEvalCase: Identifiable, Sendable {
    let id: String
    let category: String
    let input: String
    let references: [String]

    init(_ id: String, _ category: String, _ input: String, _ reference: String, alternatives: [String] = []) {
        self.id = id
        self.category = category
        self.input = input
        self.references = [reference] + alternatives
    }
}

enum GrammarEvalSuite {
    static let cases: [GrammarEvalCase] = [
        .init("agreement-1", "Agreement", "She don't like coffee.", "She doesn't like coffee."),
        .init("agreement-2", "Agreement", "The list of items are on the desk.", "The list of items is on the desk."),
        .init("agreement-3", "Agreement", "I has two apple and they is red.", "I have two apples and they are red."),
        .init("agreement-4", "Agreement", "Neither of the answers are correct.", "Neither of the answers is correct."),

        .init("article-1", "Articles", "I bought a umbrella yesterday.", "I bought an umbrella yesterday."),
        .init("article-2", "Articles", "He is best person for job.", "He is the best person for the job."),
        .init("article-3", "Articles", "She wants to become engineer.", "She wants to become an engineer."),

        .init("tense-1", "Tense", "Yesterday I go to the market.", "Yesterday I went to the market."),
        .init("tense-2", "Tense", "By next week, we finished the report.", "By next week, we will have finished the report."),
        .init("tense-3", "Tense", "I am living here since 2020.", "I have been living here since 2020."),

        .init("spelling-1", "Spelling", "The accomodation was definately comfortable.", "The accommodation was definitely comfortable."),
        .init("spelling-2", "Spelling", "Please seperate the occurences into two lists.", "Please separate the occurrences into two lists."),
        .init("spelling-3", "Spelling", "This sentance has bad grammer.", "This sentence has bad grammar."),

        .init("punctuation-1", "Punctuation", "Lets eat grandma!", "Let's eat, Grandma!"),
        .init("punctuation-2", "Punctuation", "However the deployment failed we rolled it back.", "However, the deployment failed, so we rolled it back."),
        .init("punctuation-3", "Punctuation", "Did you finish the report", "Did you finish the report?"),

        .init("word-choice-1", "Word choice", "Your going to loose access to you're account.", "You're going to lose access to your account."),
        .init("word-choice-2", "Word choice", "The new policy will effect every employee.", "The new policy will affect every employee."),
        .init("word-choice-3", "Word choice", "There project is better then ours.", "Their project is better than ours."),

        .init("clean-1", "No overcorrection", "The meeting starts at 10:30 a.m.", "The meeting starts at 10:30 a.m."),
        .init("clean-2", "No overcorrection", "Thanks! I'll take a look tomorrow.", "Thanks! I'll take a look tomorrow."),
        .init("clean-3", "No overcorrection", "Can you send me the final draft?", "Can you send me the final draft?"),
        .init("clean-4", "No overcorrection", "Honestly, this feels pretty good to me.", "Honestly, this feels pretty good to me."),

        .init("preserve-url", "Protected content", "please check https://example.com/docs?q=hello its useful", "Please check https://example.com/docs?q=hello; it's useful."),
        .init("preserve-email", "Protected content", "send it too dev-team@example.com when its ready", "Send it to dev-team@example.com when it's ready."),
        .init("preserve-code", "Protected content", "run `npm install` before you starts the app", "Run `npm install` before you start the app."),
        .init("preserve-model", "Protected content", "qwen3:0.6b work good on my M2 Mac", "qwen3:0.6b works well on my M2 Mac."),
        .init("preserve-number", "Protected content", "we processed 12,450 request in 3.5 seconds", "We processed 12,450 requests in 3.5 seconds."),
        .init("url-only", "Protected content", "https://openrouter.ai/models?q=qwen", "https://openrouter.ai/models?q=qwen"),

        .init("markdown-1", "Formatting", "- first item are ready\n- second item need review", "- The first item is ready.\n- The second item needs review."),
        .init("markdown-2", "Formatting", "**Important:** dont delete the `config.json` file", "**Important:** Don't delete the `config.json` file."),
        .init("multiline", "Formatting", "Hi Sam,\n\nI has attached the files. Please checks them.\n\nThanks", "Hi Sam,\n\nI have attached the files. Please check them.\n\nThanks"),

        .init("casual-1", "Tone preservation", "hey, i seen ur message and ill reply soon", "Hey, I saw your message and I'll reply soon."),
        .init("emoji", "Tone preservation", "this feature work great 🎉 but it need tests", "This feature works great 🎉, but it needs tests."),
        .init("contraction", "Tone preservation", "I cant believe theyre already here.", "I can't believe they're already here."),

        .init("french", "Multilingual", "Je suis allé au magasin hier et j'achète du pain.", "Je suis allé au magasin hier et j'ai acheté du pain."),
        .init("spanish", "Multilingual", "Ayer fuimos al parque y jugamos con los niño.", "Ayer fuimos al parque y jugamos con los niños."),
        .init("german", "Multilingual", "Ich habe gestern ein neuen Computer gekauft.", "Ich habe gestern einen neuen Computer gekauft.")
    ]
}

struct EvalCaseScore: Identifiable, Sendable {
    let id: String
    let category: String
    let input: String
    let expected: String
    let output: String
    let score: Double
    let exact: Bool
    let preservationPassed: Bool
    let latency: TimeInterval
    let error: String?
}

enum GrammarScorer {
    static func score(test: GrammarEvalCase, output: String, latency: TimeInterval, error: String? = nil) -> EvalCaseScore {
        guard error == nil else {
            return .init(id: test.id, category: test.category, input: test.input, expected: test.references[0], output: output, score: 0, exact: false, preservationPassed: false, latency: latency, error: error)
        }
        let cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedOutput = normalized(cleaned)
        let exact = test.references.contains { normalized($0) == normalizedOutput }
        let similarityScore = test.references.map { similarity(normalizedOutput, normalized($0)) }.max() ?? 0
        let preservation = preservesProtectedContent(from: test.input, in: cleaned) && preservesStructure(from: test.input, in: cleaned)
        let clean = !containsArtifact(cleaned)
        let normalizedInput = normalized(test.input)
        let expectedAlreadyClean = test.references.contains { normalized($0) == normalizedInput }
        let baselineDistance = test.references.map { editDistance(normalizedInput, normalized($0)) }.min() ?? 0
        let outputDistance = test.references.map { editDistance(normalizedOutput, normalized($0)) }.min() ?? 0
        let correctionProgress = baselineDistance == 0 ? (exact ? 1.0 : 0.0) : max(0, min(1, 1 - Double(outputDistance) / Double(baselineDistance)))
        var total = exact ? 100 : correctionProgress * 60 + similarityScore * 20 + (preservation ? 10 : 0) + (clean ? 10 : 0)
        if expectedAlreadyClean && !exact { total = min(total, 40) }
        if cleaned.isEmpty || !clean { total = 0 }
        return .init(id: test.id, category: test.category, input: test.input, expected: test.references[0], output: cleaned, score: total, exact: exact, preservationPassed: preservation, latency: latency, error: nil)
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).lowercased()
    }

    private static func similarity(_ lhs: String, _ rhs: String) -> Double {
        if lhs == rhs { return 1 }
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        return max(0, 1 - Double(editDistance(lhs, rhs)) / Double(max(lhs.count, rhs.count)))
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs), b = Array(rhs)
        var previous = Array(0...b.count)
        for (i, x) in a.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            for (j, y) in b.enumerated() {
                current[j + 1] = min(current[j] + 1, previous[j + 1] + 1, previous[j] + (x == y ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }

    private static func preservesProtectedContent(from input: String, in output: String) -> Bool {
        let pattern = #"https?://[^\s]+|[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|`[^`]+`|\b\d[\d,.]*\b|\b[A-Za-z0-9_-]+:\d+(?:\.\d+)*[A-Za-z0-9._-]*\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return true }
        let range = NSRange(input.startIndex..., in: input)
        return regex.matches(in: input, range: range).compactMap { Range($0.range, in: input).map { String(input[$0]) } }.allSatisfy { output.contains($0) }
    }

    private static func preservesStructure(from input: String, in output: String) -> Bool {
        let inputBreaks = input.filter { $0 == "\n" }.count
        let outputBreaks = output.filter { $0 == "\n" }.count
        if inputBreaks >= 2 && outputBreaks < inputBreaks { return false }
        for marker in ["`", "**"] where input.contains(marker) && !output.contains(marker) { return false }
        return true
    }

    private static func containsArtifact(_ value: String) -> Bool {
        let lower = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return lower.isEmpty || lower == "---" || lower.contains("<think>") || lower.contains("</think>") || lower.hasSuffix("/think") || lower.hasPrefix("corrected text:")
    }
}
