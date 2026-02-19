# Contributing to APISIX OpenFGA Authorization Plugin

Thank you for your interest in contributing to the APISIX OpenFGA Authorization Plugin! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)

## Code of Conduct

We are committed to providing a welcoming and inclusive environment for all contributors. Please be respectful and considerate in all interactions.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Set up the development environment (see [Development Setup](#development-setup))
4. Create a new branch for your changes
5. Make your changes and commit them with clear, descriptive messages
6. Push your changes to your fork
7. Submit a pull request

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with:
- A clear, descriptive title
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- Your environment (APISIX version, OpenFGA version, OS, etc.)
- Any relevant logs or error messages

### Suggesting Enhancements

We welcome suggestions for new features or improvements. Please create an issue with:
- A clear, descriptive title
- A detailed description of the proposed enhancement
- Any relevant use cases or examples
- Why this enhancement would be useful

### Contributing Code

1. Check existing issues and pull requests to avoid duplicating work
2. For significant changes, please open an issue first to discuss the proposed changes
3. Follow the coding standards and testing guidelines
4. Ensure all tests pass before submitting your pull request
5. Update documentation as needed

## Development Setup

### Prerequisites

- Apache APISIX (version 3.0 or higher recommended)
- OpenFGA instance (for testing)
- Lua 5.1 or LuaJIT
- Git

### Setting Up Your Development Environment

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/openfga_authz_plugin.git
cd openfga_authz_plugin

# Set up upstream remote
git remote add upstream https://github.com/NShanmugapriya/openfga_authz_plugin.git

# Install dependencies (if any)
# ...

# Run tests to ensure everything is working
# ...
```

## Pull Request Process

1. Update the README.md or other documentation with details of changes if applicable
2. Ensure all tests pass
3. Update the CHANGELOG.md with notes on your changes (if applicable)
4. Follow the commit message conventions (see below)
5. Request review from maintainers
6. Address any feedback from reviewers
7. Once approved, a maintainer will merge your pull request

### Commit Message Conventions

Use clear and descriptive commit messages:

```
type: subject

body (optional)

footer (optional)
```

Types:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Example:
```
feat: add caching support for authorization checks

Implement a caching mechanism to reduce latency and load on OpenFGA.
Cache TTL is configurable via plugin configuration.

Closes #123
```

## Coding Standards

### Lua Code Style

- Use 4 spaces for indentation (no tabs)
- Follow [Lua Style Guide](https://github.com/luarocks/lua-style-guide)
- Keep lines under 100 characters when possible
- Use meaningful variable and function names
- Add comments for complex logic

### Code Organization

- Keep functions focused and single-purpose
- Avoid deeply nested code
- Handle errors gracefully
- Log important events and errors

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run specific test
# ...
```

### Writing Tests

- Write tests for new features
- Update tests when modifying existing features
- Ensure tests are clear and well-documented
- Test both success and failure scenarios
- Include edge cases

## Documentation

- Update documentation for any user-facing changes
- Keep code comments up-to-date
- Add examples for new features
- Ensure documentation is clear and accurate

### Documentation Structure

- `README.md`: Main project documentation
- `docs/`: Detailed documentation
  - `configuration.md`: Configuration guide
  - `examples/`: Usage examples
  - `architecture.md`: Architecture overview (if applicable)

## Questions?

If you have questions about contributing, please:
- Open an issue with your question
- Reach out to the maintainers

Thank you for contributing! 🎉
