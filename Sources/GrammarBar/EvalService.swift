import Foundation
import Combine

struct EvalModel: Identifiable, Hashable, Sendable {
    let provider: ProviderKind
    let model: String
    let displayName: String
    let promptPricePerToken: Double?
    let completionPricePerToken: Double?

    var id: String { provider.rawValue + "::" + model }
    var priceLabel: String {
        guard let promptPricePerToken, let completionPricePerToken else {
            return provider == .openRouter ? "Price unavailable" : "Local · no API cost"
        }
        return String(format: "$%.3f / $%.3f per 1M", promptPricePerToken * 1_000_000, completionPricePerToken * 1_000_000)
    }
}

struct EvalModelResult: Identifiable, Sendable {
    let model: EvalModel
    let cases: [EvalCaseScore]
    let inputTokens: Int
    let outputTokens: Int
    let estimatedCost: Double

    var id: String { model.id }
    var score: Double { cases.isEmpty ? 0 : cases.map(\.score).reduce(0, +) / Double(cases.count) }
    var exactRate: Double { cases.isEmpty ? 0 : Double(cases.filter(\.exact).count) / Double(cases.count) }
    var preservationRate: Double { cases.isEmpty ? 0 : Double(cases.filter(\.preservationPassed).count) / Double(cases.count) }
    var averageLatency: TimeInterval { cases.isEmpty ? 0 : cases.map(\.latency).reduce(0, +) / Double(cases.count) }
    var failedCases: [EvalCaseScore] { cases.filter { $0.score < 85 } }
    var valueScore: Double { score / (1 + estimatedCost * 1_000) }
}

struct ModelCatalogService {
    func models(for provider: ProviderKind, settings: AppSettings) async throws -> [EvalModel] {
        switch provider {
        case .openRouter: return try await openRouterModels(apiKey: settings.apiKey)
        case .ollama: return try await ollamaModels(baseURL: settings.ollamaURL)
        case .lmStudio: return try await lmStudioModels(baseURL: settings.lmStudioURL)
        }
    }

    private func openRouterModels(apiKey: String) async throws -> [EvalModel] {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else { throw GrammarError.invalidURL }
        var request = URLRequest(url: url)
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        let payload = try JSONDecoder().decode(OpenRouterCatalog.self, from: data)
        return payload.data.map {
            EvalModel(provider: .openRouter, model: $0.id, displayName: $0.name ?? $0.id,
                      promptPricePerToken: Double($0.pricing?.prompt ?? ""), completionPricePerToken: Double($0.pricing?.completion ?? ""))
        }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func ollamaModels(baseURL: String) async throws -> [EvalModel] {
        guard let url = URL(string: trim(baseURL) + "/api/tags") else { throw GrammarError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response, data: data)
        return try JSONDecoder().decode(OllamaCatalog.self, from: data).models.map {
            EvalModel(provider: .ollama, model: $0.name, displayName: $0.name, promptPricePerToken: 0, completionPricePerToken: 0)
        }.sorted { $0.model < $1.model }
    }

    private func lmStudioModels(baseURL: String) async throws -> [EvalModel] {
        guard let url = URL(string: trim(baseURL) + "/v1/models") else { throw GrammarError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response, data: data)
        return try JSONDecoder().decode(LMStudioCatalog.self, from: data).data.map {
            EvalModel(provider: .lmStudio, model: $0.id, displayName: $0.id, promptPricePerToken: 0, completionPricePerToken: 0)
        }.sorted { $0.model < $1.model }
    }

    private func trim(_ value: String) -> String { value.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GrammarError.badResponse(String(data: data, encoding: .utf8) ?? "Could not load models.")
        }
    }
}

private struct OpenRouterCatalog: Decodable {
    struct Item: Decodable {
        struct Pricing: Decodable { let prompt: String; let completion: String }
        let id: String
        let name: String?
        let pricing: Pricing?
    }
    let data: [Item]
}
private struct OllamaCatalog: Decodable { struct Item: Decodable { let name: String }; let models: [Item] }
private struct LMStudioCatalog: Decodable { struct Item: Decodable { let id: String }; let data: [Item] }

@MainActor
final class EvalDashboardModel: ObservableObject {
    @Published var browserProvider: ProviderKind
    @Published var availableModels: [EvalModel] = []
    @Published var selectedIDs: Set<String> = []
    @Published var results: [EvalModelResult] = []
    @Published var search = ""
    @Published var isLoadingModels = false
    @Published var isRunning = false
    @Published var completedCases = 0
    @Published var totalCases = 0
    @Published var errorMessage: String?

    let settings: AppSettings
    private let catalog = ModelCatalogService()
    private let client = GrammarClient()
    private var runTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
        browserProvider = settings.provider
        let current = EvalModel(provider: settings.provider, model: settings.model, displayName: settings.model,
                                promptPricePerToken: settings.provider == .openRouter ? nil : 0,
                                completionPricePerToken: settings.provider == .openRouter ? nil : 0)
        availableModels = [current]
        selectedIDs = [current.id]
    }

    var filteredModels: [EvalModel] {
        guard !search.isEmpty else { return availableModels.filter { $0.provider == browserProvider } }
        return availableModels.filter { $0.provider == browserProvider && ($0.model.localizedCaseInsensitiveContains(search) || $0.displayName.localizedCaseInsensitiveContains(search)) }
    }

    var selectedModels: [EvalModel] { availableModels.filter { selectedIDs.contains($0.id) } }

    func refreshModels() {
        isLoadingModels = true
        errorMessage = nil
        let provider = browserProvider
        Task {
            do {
                let discovered = try await catalog.models(for: provider, settings: settings)
                availableModels.removeAll { $0.provider == provider }
                availableModels.append(contentsOf: discovered)
                if discovered.isEmpty { errorMessage = "No models were returned by \(provider.rawValue)." }
            } catch { errorMessage = error.localizedDescription }
            isLoadingModels = false
        }
    }

    func toggle(_ model: EvalModel) {
        if selectedIDs.contains(model.id) { selectedIDs.remove(model.id) } else { selectedIDs.insert(model.id) }
    }

    func run(fullSuite: Bool) {
        let candidates = selectedModels
        guard !candidates.isEmpty, !isRunning else { return }
        let tests = fullSuite ? GrammarEvalSuite.cases : Array(GrammarEvalSuite.cases.prefix(12))
        isRunning = true
        results = []
        completedCases = 0
        totalCases = candidates.count * tests.count
        errorMessage = nil
        runTask = Task {
            for candidate in candidates {
                if Task.isCancelled { break }
                var caseScores: [EvalCaseScore] = []
                var inputTokens = 0
                var outputTokens = 0
                for test in tests {
                    if Task.isCancelled { break }
                    let start = Date()
                    do {
                        let completion = try await client.complete(test.input, using: configuration(for: candidate))
                        let latency = Date().timeIntervalSince(start)
                        inputTokens += completion.inputTokens
                        outputTokens += completion.outputTokens
                        caseScores.append(GrammarScorer.score(test: test, output: completion.text, latency: latency))
                    } catch {
                        caseScores.append(GrammarScorer.score(test: test, output: "", latency: Date().timeIntervalSince(start), error: error.localizedDescription))
                    }
                    completedCases += 1
                }
                let cost = Double(inputTokens) * (candidate.promptPricePerToken ?? 0) + Double(outputTokens) * (candidate.completionPricePerToken ?? 0)
                results.append(.init(model: candidate, cases: caseScores, inputTokens: inputTokens, outputTokens: outputTokens, estimatedCost: cost))
                results.sort { $0.score > $1.score }
            }
            isRunning = false
        }
    }

    func cancel() { runTask?.cancel(); isRunning = false }

    func badges(for result: EvalModelResult) -> [String] {
        guard !results.isEmpty else { return [] }
        var values: [String] = []
        if result.id == results.max(by: { $0.score < $1.score })?.id { values.append("Best accuracy") }
        if result.id == results.min(by: { $0.averageLatency < $1.averageLatency })?.id { values.append("Fastest") }
        if result.id == results.min(by: { $0.estimatedCost < $1.estimatedCost })?.id { values.append("Cheapest") }
        if result.id == results.max(by: { $0.valueScore < $1.valueScore })?.id { values.append("Best value") }
        return values
    }

    private func configuration(for model: EvalModel) -> GrammarConfiguration {
        .init(provider: model.provider, model: model.model, apiKey: settings.apiKey,
              ollamaURL: settings.ollamaURL, lmStudioURL: settings.lmStudioURL)
    }
}
