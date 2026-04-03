# Contributing

Thanks for your interest in contributing to Kapt!

## Reporting Issues

- Use [GitHub Issues](https://github.com/sonpiaz/kapt/issues) to report bugs
- Include steps to reproduce, expected vs actual behavior, and your macOS version

## Submitting PRs

1. Fork the repo and create a branch from `main`
2. Name your branch `feat/description` or `fix/description`
3. Make your changes and ensure `swift build -c release` passes
4. Write a clear PR description explaining what changed and why
5. Submit the PR against `main`

## Local Development

```bash
git clone https://github.com/sonpiaz/kapt.git
cd kapt
./scripts/dev.sh    # Quick dev cycle (~3 seconds)
```

## Code Style

- Swift 6 strict concurrency
- SwiftUI for all UI
- Follow existing patterns in the codebase
- No third-party dependencies unless absolutely necessary
