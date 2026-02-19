# OpenFGA Authorization Plugin for Apache APISIX

This plugin integrates [OpenFGA](https://openfga.dev/) (Fine-Grained Authorization) with [Apache APISIX](https://apisix.apache.org/), enabling fine-grained authorization checks directly in your API gateway.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## Table of Contents

- [Why This Plugin?](#why-this-plugin)
- [How It Works](#how-it-works)
- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Examples](#examples)
- [Performance Considerations](#performance-considerations)
- [Contributing](#contributing)
- [License](#license)

## Why This Plugin?

Modern applications require sophisticated authorization systems that can handle complex access control scenarios. While Apache APISIX provides excellent API gateway capabilities, it lacks native support for fine-grained authorization. OpenFGA fills this gap with its powerful authorization model based on Google's Zanzibar paper.

This plugin bridges the gap between Apache APISIX and OpenFGA, allowing you to:

1. **Implement fine-grained access control** at the API gateway level
2. **Centralize authorization logic**, reducing duplication across microservices
3. **Easily manage and update** access control policies without changing application code
4. **Scale authorization checks efficiently**, leveraging OpenFGA's performance

## How It Works

The plugin intercepts incoming requests to Apache APISIX and performs authorization checks against OpenFGA before allowing the request to proceed to upstream services.

**Request Flow:**

1. Client sends a request to APISIX with user identification (e.g., in a header)
2. The plugin extracts:
   - User identity from configured header
   - Resource ID from the URI, query parameter, or header
   - Required relation based on HTTP method
3. Plugin queries OpenFGA to check if the user has the required relation to the resource
4. If authorized, request proceeds to upstream service
5. If denied, plugin returns 403 Forbidden

**Caching:**

- Authorization decisions can be cached to reduce latency
- Configurable TTL for cache entries
- Cache key based on user, resource, and relation tuple

## Features

- ✅ Seamless integration of OpenFGA authorization with Apache APISIX
- ✅ Flexible resource ID extraction (URI path, query param, header)
- ✅ Customizable relation mapping based on HTTP methods
- ✅ Support for multiple OpenFGA authorization models
- ✅ Built-in caching for improved performance
- ✅ Detailed logging and error handling
- ✅ Configurable timeouts and SSL verification
- ✅ No external dependencies beyond standard APISIX libraries

## Installation

### Prerequisites

- Apache APISIX 3.0 or higher
- OpenFGA server instance
- Access to APISIX configuration

### Method 1: Manual Installation

1. Copy the plugin file to your APISIX plugins directory:

```bash
cp apisix/plugins/openfga-authz.lua /path/to/apisix/apisix/plugins/
```

2. Add the plugin to your APISIX configuration (`config.yaml`):

```yaml
plugins:
  - ... # other plugins
  - openfga-authz
```

3. Reload or restart Apache APISIX:

```bash
apisix reload
# or
apisix restart
```

### Method 2: Using Custom Plugins Directory

1. Clone this repository:

```bash
git clone https://github.com/NShanmugapriya/openfga_authz_plugin.git
```

2. Configure APISIX to load custom plugins from this directory by adding to `config.yaml`:

```yaml
apisix:
  extra_lua_path: "/path/to/openfga_authz_plugin/?.lua"

plugins:
  - ... # other plugins
  - openfga-authz
```

3. Reload APISIX:

```bash
apisix reload
```

## Configuration

### Plugin Configuration Schema

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `openfga_url` | string | Yes | - | OpenFGA server URL (e.g., `https://api.openfga.example`) |
| `store_id` | string | Yes | - | OpenFGA store ID |
| `authorization_model_id` | string | No | - | Specific authorization model ID (uses latest if not specified) |
| `user_header` | string | No | `X-User-ID` | HTTP header containing user identifier |
| `resource_type` | string | Yes | - | OpenFGA resource type (e.g., `document`, `folder`) |
| `relation_mapping` | object | No | See below | Map of HTTP methods to OpenFGA relations |
| `id_location` | string | No | `last_path_segment` | Where to find resource ID: `last_path_segment`, `query_param`, or `header` |
| `id_param_name` | string | No | - | Query parameter or header name for resource ID |
| `cache_ttl` | integer | No | 300 | Cache TTL in seconds (0 to disable) |
| `timeout` | integer | No | 3000 | OpenFGA request timeout in milliseconds |
| `ssl_verify` | boolean | No | true | Verify SSL certificates |

### Default Relation Mapping

If `relation_mapping` is not specified, the following defaults are used:

```lua
{
  GET = "reader",
  POST = "writer",
  PUT = "writer",
  PATCH = "writer",
  DELETE = "admin"
}
```

### Example: Route Configuration

```bash
curl http://127.0.0.1:9180/apisix/admin/routes/1 \
-H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT -d '
{
  "uri": "/api/documents/*",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://api.fga.example",
      "store_id": "01HXXX...",
      "authorization_model_id": "01HYYY...",
      "user_header": "X-User-ID",
      "resource_type": "document",
      "relation_mapping": {
        "GET": "viewer",
        "POST": "editor",
        "PUT": "editor",
        "DELETE": "owner"
      },
      "id_location": "last_path_segment",
      "cache_ttl": 300
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "httpbin.org:80": 1
    }
  }
}'
```

## Usage

### Basic Usage

Once configured, the plugin automatically checks authorization for all requests matching the route.

**Example Request:**

```bash
curl -H "X-User-ID: user:alice" \
  http://your-apisix-instance/api/documents/123
```

This request:
1. Extracts user: `user:alice`
2. Extracts resource: `document:123`
3. Determines relation: `viewer` (for GET method)
4. Checks with OpenFGA if `user:alice` has `viewer` relation to `document:123`
5. Allows or denies the request based on the result

### Advanced Usage Examples

#### Using Query Parameter for Resource ID

```json
{
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://api.fga.example",
      "store_id": "01HXXX...",
      "resource_type": "file",
      "id_location": "query_param",
      "id_param_name": "file_id"
    }
  }
}
```

Request: `GET /api/files?file_id=456`

#### Using Header for Resource ID

```json
{
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://api.fga.example",
      "store_id": "01HXXX...",
      "resource_type": "resource",
      "id_location": "header",
      "id_param_name": "X-Resource-ID"
    }
  }
}
```

Request with header: `X-Resource-ID: 789`

## Examples

See the [examples](./examples/) directory for complete configuration examples:

- [Basic Document Authorization](./examples/basic-document-authz.md)
- [Multi-Resource Configuration](./examples/multi-resource.md)
- [Custom Relation Mapping](./examples/custom-relations.md)

## Performance Considerations

The plugin is designed with performance in mind:

### Caching

- Authorization decisions are cached using LRU cache
- Default TTL: 300 seconds (configurable)
- Cache key format: `{user}:{resource_type}:{resource_id}:{relation}`
- Set `cache_ttl: 0` to disable caching

### Timeouts

- Default timeout: 3000ms
- Configurable per route
- Consider your OpenFGA server latency when setting timeouts

### Connection Management

- Uses `resty.http` for HTTP connections
- Supports connection pooling
- SSL verification can be disabled for development (not recommended for production)

### Best Practices

1. **Enable caching** for frequently accessed resources
2. **Set appropriate TTL** based on how often permissions change
3. **Monitor OpenFGA performance** and adjust timeouts accordingly
4. **Use specific authorization models** when possible
5. **Implement proper error handling** in your upstream services

## Troubleshooting

### Common Issues

**1. "User header not found"**
- Ensure the user identifier is sent in the configured header (default: `X-User-ID`)
- Check that upstream authentication is working correctly

**2. "Resource ID not found"**
- Verify `id_location` setting matches your URI structure
- Check that resource IDs are present in the expected location

**3. "OpenFGA request failed"**
- Verify `openfga_url` is correct and reachable from APISIX
- Check OpenFGA server is running and accessible
- Review OpenFGA server logs for errors

**4. High latency**
- Enable caching with appropriate TTL
- Check network latency to OpenFGA server
- Consider deploying OpenFGA closer to APISIX

### Debug Logging

Enable APISIX debug logging to see detailed plugin execution:

```yaml
nginx_config:
  error_log_level: "debug"
```

## Architecture

The plugin follows APISIX's standard plugin architecture:

- **Schema validation**: Ensures configuration is valid
- **Access phase**: Executes authorization check during request processing
- **Priority**: 2555 (runs before most other plugins but after authentication)

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details on:

- Reporting bugs
- Suggesting enhancements
- Submitting pull requests
- Code standards and testing guidelines

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Apache APISIX](https://apisix.apache.org/) - The API Gateway
- [OpenFGA](https://openfga.dev/) - Fine-Grained Authorization
- Inspired by [Google Zanzibar](https://research.google/pubs/pub48190/) paper

## Support

- **Issues**: [GitHub Issues](https://github.com/NShanmugapriya/openfga_authz_plugin/issues)
- **Discussions**: [GitHub Discussions](https://github.com/NShanmugapriya/openfga_authz_plugin/discussions)

## Roadmap

Future enhancements planned:

- [ ] Support for batch authorization checks
- [ ] Integration with APISIX Consumer authentication
- [ ] Prometheus metrics for monitoring
- [ ] Support for OpenFGA streaming API
- [ ] Admin API for dynamic configuration
- [ ] Integration tests with test containers

---

**Note**: This plugin requires Apache APISIX 3.0+ and a running OpenFGA instance. For production use, ensure proper security measures including SSL/TLS and network isolation.
