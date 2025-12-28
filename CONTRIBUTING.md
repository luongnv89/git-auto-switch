# Contributing to git-auto-switch

Thank you for your interest in contributing!

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/luongnv89/git-auto-switch.git
   cd git-auto-switch
   ```

2. Install development dependencies:
   ```bash
   # macOS
   brew install shellcheck bats-core

   # Ubuntu/Debian
   sudo apt-get install shellcheck bats
   ```

3. Verify your setup:
   ```bash
   make check-deps
   ```

## Running Tests

```bash
# Run all tests
make test

# Run specific test file
bats test/cleanup.bats

# Run with verbose output
bats --verbose-run test/
```

## Running Linter

```bash
make lint
```

## Code Style

- Use 2-space indentation
- Quote variables: `"$var"` not `$var`
- Use `[[ ]]` for conditionals (bash-specific)
- Use `read -r` to avoid backslash escaping issues
- Add comments for non-obvious logic
- Follow existing patterns in the codebase

## Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Run `make all` to ensure lint and tests pass
5. Commit with a descriptive message
6. Push and open a Pull Request

## Reporting Issues

Please include:
- Your operating system and version
- Bash version (`bash --version`)
- Steps to reproduce the issue
- Expected vs actual behavior
