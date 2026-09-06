import SwiftUI

struct EvalDashboardView: View {
    @StateObject private var model: EvalDashboardModel
    @State private var fullSuite = false

    init(settings: AppSettings) {
        _model = StateObject(wrappedValue: EvalDashboardModel(settings: settings))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                modelPicker.frame(minWidth: 300, idealWidth: 340)
                resultsPanel.frame(minWidth: 520)
            }
        }
        .frame(width: 920, height: 680)
        .tint(.primary)
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Grammar model evals").font(.title2.bold())
                Text("Accuracy, preservation, latency, and cost on \(GrammarEvalSuite.cases.count) tests")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Suite", selection: $fullSuite) {
                Text("Quick · 12").tag(false)
                Text("Full · \(GrammarEvalSuite.cases.count)").tag(true)
            }.pickerStyle(.segmented).frame(width: 190)
            if model.isRunning {
                Button("Cancel") { model.cancel() }
            } else {
                Button("Run evals") { model.run(fullSuite: fullSuite) }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.selectedIDs.isEmpty)
            }
        }.padding(20)
    }

    private var modelPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Models").font(.headline)
            Picker("Provider", selection: $model.browserProvider) {
                ForEach(ProviderKind.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            HStack {
                TextField("Search models", text: $model.search)
                Button {
                    model.refreshModels()
                } label: {
                    if model.isLoadingModels { ProgressView().controlSize(.small) }
                    else { Image(systemName: "arrow.clockwise") }
                }.disabled(model.isLoadingModels)
            }
            if let message = model.errorMessage {
                Text(message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            List(model.filteredModels.prefix(150)) { candidate in
                Button { model.toggle(candidate) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: model.selectedIDs.contains(candidate.id) ? "checkmark.square.fill" : "square")
                        VStack(alignment: .leading, spacing: 3) {
                            Text(candidate.displayName).lineLimit(1)
                            Text(candidate.priceLabel).font(.caption2).foregroundStyle(.secondary)
                        }
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            Text("\(model.selectedIDs.count) selected · Refresh each provider to compare its models")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(16)
    }

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isRunning {
                ProgressView(value: Double(model.completedCases), total: Double(max(1, model.totalCases)))
                Text("Running case \(model.completedCases) of \(model.totalCases)…")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if model.results.isEmpty && !model.isRunning {
                ContentUnavailableView("No results yet", systemImage: "chart.bar.xaxis", description: Text("Select two or more models, then run the quick or full suite."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.results) { result in resultCard(result) }
                    }.padding(.vertical, 2)
                }
            }
        }.padding(16)
    }

    private func resultCard(_ result: EvalModelResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.model.displayName).font(.headline)
                    Text(result.model.provider.rawValue).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%.1f", result.score)).font(.system(size: 28, weight: .bold, design: .rounded))
                Text("/100").foregroundStyle(.secondary)
            }
            HStack(spacing: 18) {
                metric("Exact", String(format: "%.0f%%", result.exactRate * 100))
                metric("Protected", String(format: "%.0f%%", result.preservationRate * 100))
                metric("Latency", String(format: "%.2fs", result.averageLatency))
                metric("Eval cost", result.model.provider == .openRouter ? String(format: "$%.4f", result.estimatedCost) : "$0 local")
            }
            let badges = model.badges(for: result)
            if !badges.isEmpty {
                HStack { ForEach(badges, id: \.self) { Text($0).font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 4).overlay(Capsule().stroke(.primary)) } }
            }
            if !result.failedCases.isEmpty {
                DisclosureGroup("\(result.failedCases.count) weak cases") {
                    ForEach(result.failedCases.prefix(10)) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(item.category) · \(Int(item.score))/100").font(.caption.bold())
                            Text("Input: \(item.input)").font(.caption)
                            Text(item.error.map { "Error: \($0)" } ?? "Output: \(item.output)").font(.caption).foregroundStyle(.secondary)
                            Text("Expected: \(item.expected)").font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
                    }
                }.font(.caption)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.15)))
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(.body, design: .rounded).bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
