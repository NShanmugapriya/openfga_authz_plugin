# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of OpenFGA Authorization Plugin for Apache APISIX
- Core plugin implementation with OpenFGA integration
- Support for configurable resource ID extraction (path segment, query param, header)
- Customizable HTTP method to OpenFGA relation mapping
- Built-in caching with configurable TTL
- Comprehensive documentation including:
  - README with features and usage
  - Configuration guide with all parameters
  - Getting Started guide
  - Multiple usage examples (basic, multi-resource, custom relations)
- Docker Compose setup for local development and testing
- GitHub Actions workflows for CI/CD:
  - Lint workflow for Lua and Markdown
  - Integration test workflow
- Contributing guidelines
- Apache 2.0 License
- Example configurations for common use cases
- Makefile for common development tasks

### Features
- Fine-grained authorization at API gateway level
- Support for multiple resource types
- Flexible relation mapping
- Performance optimization through caching
- Detailed logging for debugging
- SSL/TLS support with configurable verification
- Timeout configuration for OpenFGA requests

## [0.1.0] - 2024-XX-XX

### Initial Development
- Project structure created
- Basic plugin skeleton implemented
- Documentation framework established

---

## Release Notes

### Version 0.1.0 (Upcoming)

This is the initial release of the OpenFGA Authorization Plugin for Apache APISIX.

**Key Features:**
- ✅ Seamless OpenFGA integration
- ✅ Flexible configuration options
- ✅ High performance with caching
- ✅ Comprehensive documentation
- ✅ Docker-based development environment
- ✅ CI/CD pipeline

**Requirements:**
- Apache APISIX 3.0 or higher
- OpenFGA server instance
- Lua 5.1 or LuaJIT

**Installation:**
See [Getting Started Guide](docs/getting-started.md) for installation instructions.

**Known Limitations:**
- Cache size is fixed at 200 entries
- No support for batch authorization checks
- Limited to single OpenFGA store per route

**Future Plans:**
- Support for batch authorization
- Prometheus metrics
- Enhanced caching strategies
- Admin API integration
- More comprehensive test suite
