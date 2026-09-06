import Foundation

@main
enum EvalScorerSmoke {
    static func main() {
        let exactCase = GrammarEvalCase("exact", "Test", "She don't go.", "She doesn't go.")
        let exact = GrammarScorer.score(test: exactCase, output: "She doesn't go.", latency: 0.1)
        precondition(exact.score == 100 && exact.exact)

        let protectedCase = GrammarEvalCase("url", "Test", "visit https://example.com it work", "Visit https://example.com; it works.")
        let damaged = GrammarScorer.score(test: protectedCase, output: "Visit https://example.org; it works.", latency: 0.1)
        precondition(!damaged.preservationPassed && damaged.score < 85)

        let artifact = GrammarScorer.score(test: exactCase, output: "---", latency: 0.1)
        precondition(artifact.score == 0)
        print("Eval scorer smoke test passed")
    }
}
