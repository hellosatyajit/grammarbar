# GrammarBar

A native Swift macOS menu-bar app that fixes grammar in the focused text field using OpenRouter, Ollama, or LM Studio.

## Build and run

Requires macOS 14+ and Xcode Command Line Tools.

```sh
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open dist/GrammarBar.app
```

Run `./scripts/verify.sh` to create and validate a signed release bundle.
If Ollama is running, `./scripts/test-ollama.sh qwen3:0.6b` verifies the configured local model.

## Model evals

Choose **Evals Dashboard…** from the menu-bar menu. Refresh OpenRouter, Ollama, or LM Studio to discover available models, select the models to compare, and run either the 12-case quick suite or the full 37-case suite.

The dashboard ranks models using reference-answer similarity, exact-match rate, URL/code/number and formatting preservation, output-artifact detection, average latency, token usage, and estimated OpenRouter cost. Local providers show zero API cost. Scores are deterministic regression indicators rather than a substitute for human review; inspect the weak cases shown under each result before choosing a model.

For a terminal benchmark of an Ollama model, run `./scripts/benchmark-ollama.sh qwen3:0.6b 12`.

On first launch, grant Accessibility permission. Choose a provider and model in Settings. Select text (or leave nothing selected to correct the entire focused field), then press **Right Command + Right Option**. The shortcut is configurable.

OpenRouter keys are stored in macOS Keychain. Ollama defaults to `http://127.0.0.1:11434`; LM Studio defaults to `http://127.0.0.1:1234`.
