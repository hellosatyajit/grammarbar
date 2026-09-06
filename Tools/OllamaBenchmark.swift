import Foundation

@main
enum OllamaBenchmark {
    static func main() async {
        let model = CommandLine.arguments.dropFirst().first ?? "qwen3:0.6b"
        let count = Int(CommandLine.arguments.dropFirst(2).first ?? "12") ?? 12
        let tests = Array(GrammarEvalSuite.cases.prefix(min(count, GrammarEvalSuite.cases.count)))
        let configuration = GrammarConfiguration(provider: .ollama, model: model, apiKey: "",
                                                  ollamaURL: "http://127.0.0.1:11434", lmStudioURL: "http://127.0.0.1:1234")
        let client = GrammarClient()
        var scores: [EvalCaseScore] = []
        for test in tests {
            let start = Date()
            do {
                let completion = try await client.complete(test.input, using: configuration)
                let result = GrammarScorer.score(test: test, output: completion.text, latency: Date().timeIntervalSince(start))
                scores.append(result)
                print(String(format: "%3.0f  %@  %@", result.score, test.id, completion.text.replacingOccurrences(of: "\n", with: " ↵ ")))
            } catch {
                let result = GrammarScorer.score(test: test, output: "", latency: Date().timeIntervalSince(start), error: error.localizedDescription)
                scores.append(result)
                print("  0  \(test.id)  ERROR: \(error.localizedDescription)")
            }
        }
        let average = scores.map(\.score).reduce(0, +) / Double(max(1, scores.count))
        let exact = Double(scores.filter(\.exact).count) / Double(max(1, scores.count)) * 100
        let latency = scores.map(\.latency).reduce(0, +) / Double(max(1, scores.count))
        print(String(format: "\n%@ · %.1f/100 · %.0f%% exact · %.2fs average · %d cases", model, average, exact, latency, scores.count))
    }
}
