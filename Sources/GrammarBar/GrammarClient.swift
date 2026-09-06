import Foundation

enum GrammarError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case badResponse(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Add your OpenRouter API key in Settings."
        case .invalidURL: return "The provider URL is invalid."
        case .badResponse(let message): return message
        case .emptyResponse: return "The model returned no corrected text."
        }
    }
}

struct GrammarConfiguration: Sendable {
    let provider: ProviderKind
    let model: String
    let apiKey: String
    let ollamaURL: String
    let lmStudioURL: String
}

struct GrammarCompletion: Sendable {
    let text: String
    let inputTokens: Int
    let outputTokens: Int
}

struct GrammarClient {
    private let systemPrompt = """
    You are a grammar correction engine. Fix every grammar, spelling, punctuation, capitalization, and word-form error. Preserve meaning, language, tone, and formatting. Never change URLs, email addresses, code, paths, commands, names, model names, usernames, or identifiers. Return only the corrected text with no explanation, reasoning, quotation marks, labels, or preamble.
    """

    func correct(_ text: String, using config: GrammarConfiguration) async throws -> String {
        try await complete(text, using: config).text
    }

    func complete(_ text: String, using config: GrammarConfiguration) async throws -> GrammarCompletion {
        if shouldRemainUnchanged(text) {
            return GrammarCompletion(text: text, inputTokens: 0, outputTokens: 0)
        }
        switch config.provider {
        case .openRouter:
            guard !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw GrammarError.missingAPIKey }
            return try await openAICompatible(text, endpoint: "https://openrouter.ai/api/v1/chat/completions", model: config.model, apiKey: config.apiKey, openRouter: true)
        case .lmStudio:
            return try await openAICompatible(text, endpoint: normalized(config.lmStudioURL) + "/v1/chat/completions", model: config.model, apiKey: nil, openRouter: false)
        case .ollama:
            return try await ollama(text, endpoint: normalized(config.ollamaURL) + "/api/chat", model: config.model)
        }
    }

    private func normalized(_ value: String) -> String { value.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }

    private func openAICompatible(_ text: String, endpoint: String, model: String, apiKey: String?, openRouter: Bool) async throws -> GrammarCompletion {
        guard let url = URL(string: endpoint) else { throw GrammarError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        if openRouter {
            request.setValue("GrammarBar", forHTTPHeaderField: "X-Title")
            request.setValue("https://github.com/grammarbar", forHTTPHeaderField: "HTTP-Referer")
        }
        request.httpBody = try JSONEncoder().encode(ChatRequest(model: model, messages: [
            .init(role: "system", content: systemPrompt), .init(role: "user", content: correctionRequest(text))
        ], temperature: 0))
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let raw = decoded.choices.first?.message.content else { throw GrammarError.emptyResponse }
        let result = cleaned(raw)
        guard !result.isEmpty else { throw GrammarError.emptyResponse }
        return GrammarCompletion(text: result, inputTokens: decoded.usage?.promptTokens ?? estimateTokens(systemPrompt + text), outputTokens: decoded.usage?.completionTokens ?? estimateTokens(result))
    }

    private func ollama(_ text: String, endpoint: String, model: String) async throws -> GrammarCompletion {
        guard let url = URL(string: endpoint) else { throw GrammarError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(OllamaRequest(model: model, messages: [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: correctionRequest(text))
        ], stream: false, think: true, options: .init(temperature: 0)))
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        let decoded = try JSONDecoder().decode(OllamaResponse.self, from: data)
        let result = cleaned(decoded.message.content)
        guard !result.isEmpty else { throw GrammarError.emptyResponse }
        return GrammarCompletion(text: result, inputTokens: decoded.promptEvalCount ?? estimateTokens(systemPrompt + text), outputTokens: decoded.evalCount ?? estimateTokens(result))
    }

    private func correctionRequest(_ text: String) -> String {
        "Correct the grammar in the following text. Output only the corrected text:\n\n\(text)"
    }

    private func shouldRemainUnchanged(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains(where: { $0.isWhitespace }) else { return false }
        if let url = URL(string: value), let scheme = url.scheme, ["http", "https", "mailto", "file"].contains(scheme.lowercased()) { return true }
        if value.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil { return true }
        return value.range(of: #"^(?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,}(?:[/?:#][^\s]*)?$"#, options: .regularExpression) != nil
    }

    private func cleaned(_ response: String) -> String {
        var value = response
        value = value.replacingOccurrences(of: #"(?is)<think>.*?</think>"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?im)^\s*</?think>\s*$"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?im)^\s*/think\s*$"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)\s*</?think>\s*$"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)\s*/think\s*$"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?m)^\s*---\s*$"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)^\s*(?:corrected text|correction)\s*:\s*"#, with: "", options: .regularExpression)
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func estimateTokens(_ value: String) -> Int { max(1, Int(ceil(Double(value.count) / 4.0))) }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw GrammarError.badResponse("No response from the model provider.") }
        guard (200..<300).contains(http.statusCode) else {
            let payload = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data).error.message)
                ?? String(data: data, encoding: .utf8) ?? "Unknown provider error"
            throw GrammarError.badResponse("Provider error \(http.statusCode): \(payload)")
        }
    }
}

private struct Message: Codable { let role: String; let content: String }
private struct ChatRequest: Encodable { let model: String; let messages: [Message]; let temperature: Double }
private struct ChatResponse: Decodable {
    struct Choice: Decodable { let message: Message }
    struct Usage: Decodable {
        let promptTokens: Int
        let completionTokens: Int
        enum CodingKeys: String, CodingKey { case promptTokens = "prompt_tokens"; case completionTokens = "completion_tokens" }
    }
    let choices: [Choice]
    let usage: Usage?
}
private struct OllamaRequest: Encodable {
    struct Options: Encodable { let temperature: Double }
    let model: String
    let messages: [Message]
    let stream: Bool
    let think: Bool
    let options: Options
}
private struct OllamaResponse: Decodable {
    let message: Message
    let promptEvalCount: Int?
    let evalCount: Int?
    enum CodingKeys: String, CodingKey { case message; case promptEvalCount = "prompt_eval_count"; case evalCount = "eval_count" }
}
private struct APIErrorEnvelope: Decodable { struct Detail: Decodable { let message: String }; let error: Detail }
