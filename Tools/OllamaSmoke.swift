import Foundation

@main
enum OllamaSmoke {
    static func main() async throws {
        let model = CommandLine.arguments.dropFirst().first ?? "qwen3:0.6b"
        let configuration = GrammarConfiguration(
            provider: .ollama,
            model: model,
            apiKey: "",
            ollamaURL: "http://127.0.0.1:11434",
            lmStudioURL: "http://127.0.0.1:1234"
        )
        let client = GrammarClient()
        let corrected = try await client.correct("I has two apple and they is red.", using: configuration)
        guard !corrected.lowercased().contains("think") else {
            throw GrammarError.badResponse("The model leaked a thinking marker: \(corrected)")
        }
        guard !corrected.isEmpty, corrected != "---" else {
            throw GrammarError.badResponse("The model returned an invalid correction: \(corrected)")
        }
        for sample in ["this are bad grammer", "i has a apple", "she dont likes it"] {
            let result = try await client.correct(sample, using: configuration)
            guard !result.isEmpty, result != "---", !result.contains("<think>") else {
                throw GrammarError.badResponse("Invalid short-selection result for '\(sample)': \(result)")
            }
            print("Short selection: \(sample) → \(result)")
        }
        let url = "https://example.com/a-path?q=hello"
        guard try await client.correct(url, using: configuration) == url else {
            throw GrammarError.badResponse("A URL was unexpectedly changed.")
        }
        print("Corrected sample: \(corrected)")
        print("URL preservation passed")
    }
}
