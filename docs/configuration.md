# Configuration Guide

This guide provides detailed information about configuring the OpenFGA Authorization Plugin for Apache APISIX.

## Table of Contents

- [Overview](#overview)
- [Configuration Parameters](#configuration-parameters)
- [Resource ID Extraction](#resource-id-extraction)
- [Relation Mapping](#relation-mapping)
- [Caching Configuration](#caching-configuration)
- [Security Settings](#security-settings)
- [Complete Examples](#complete-examples)

## Overview

The plugin can be configured at the route level, service level, or globally in APISIX. Configuration determines how the plugin:

1. Connects to OpenFGA
2. Extracts user identity and resource information
3. Maps HTTP operations to OpenFGA relations
4. Caches authorization decisions

## Configuration Parameters

### Required Parameters

#### `openfga_url`

- **Type**: string
- **Required**: Yes
- **Description**: The base URL of your OpenFGA server
- **Example**: `https://api.fga.example.com`, `http://localhost:8080`

```json
{
  "openfga_url": "https://api.fga.example.com"
}
```

#### `store_id`

- **Type**: string
- **Required**: Yes
- **Description**: The OpenFGA store ID where your authorization model is stored
- **Example**: `01HXXX...`

You can find your store ID in the OpenFGA dashboard or by listing stores via the API.

```json
{
  "store_id": "01HXXXXXXXXXXXXXXXXXXX"
}
```

#### `resource_type`

- **Type**: string
- **Required**: Yes
- **Description**: The type of resource being protected (as defined in your OpenFGA model)
- **Example**: `document`, `folder`, `file`, `project`

```json
{
  "resource_type": "document"
}
```

### Optional Parameters

#### `authorization_model_id`

- **Type**: string
- **Required**: No
- **Default**: Uses the latest model
- **Description**: Specific authorization model version to use

```json
{
  "authorization_model_id": "01HYYYYYYYYYYYYYYYYYYY"
}
```

**When to use**: Specify this when you want to ensure a specific version of your authorization model is used, preventing automatic updates.

#### `user_header`

- **Type**: string
- **Required**: No
- **Default**: `X-User-ID`
- **Description**: HTTP header name containing the user identifier

```json
{
  "user_header": "X-User-ID"
}
```

**Common values**:
- `X-User-ID`: Default, simple user ID
- `Authorization`: If extracting from JWT (requires additional processing)
- `X-Subject`: From upstream authentication

#### `cache_ttl`

- **Type**: integer
- **Required**: No
- **Default**: 300 (5 minutes)
- **Minimum**: 0
- **Description**: Time-to-live for cached authorization decisions in seconds

```json
{
  "cache_ttl": 600
}
```

**Values**:
- `0`: Disable caching (every request checks OpenFGA)
- `60-300`: Low TTL for frequently changing permissions
- `300-3600`: Standard TTL for stable permissions
- `3600+`: High TTL for rarely changing permissions

#### `timeout`

- **Type**: integer
- **Required**: No
- **Default**: 3000 (3 seconds)
- **Minimum**: 1
- **Description**: Timeout for OpenFGA requests in milliseconds

```json
{
  "timeout": 5000
}
```

**Considerations**:
- Set based on your OpenFGA server latency
- Too low: Requests may fail unnecessarily
- Too high: Slow authorization checks impact user experience

#### `ssl_verify`

- **Type**: boolean
- **Required**: No
- **Default**: true
- **Description**: Whether to verify SSL certificates when connecting to OpenFGA

```json
{
  "ssl_verify": true
}
```

**Important**: Set to `false` only in development environments. Always use `true` in production.

## Resource ID Extraction

The plugin needs to extract the resource ID from the request. Configure this with `id_location` and optionally `id_param_name`.

### `id_location`

- **Type**: string
- **Required**: No
- **Default**: `last_path_segment`
- **Allowed values**: `last_path_segment`, `query_param`, `header`

### Configuration Options

#### Option 1: Last Path Segment (Default)

Extracts the resource ID from the last segment of the URI path.

```json
{
  "id_location": "last_path_segment"
}
```

**Examples**:
- `/api/documents/123` → Resource ID: `123`
- `/api/v1/files/abc-def` → Resource ID: `abc-def`
- `/users/alice/documents/456` → Resource ID: `456`

**Best for**: RESTful APIs where resource ID is in the path

#### Option 2: Query Parameter

Extracts the resource ID from a query parameter.

```json
{
  "id_location": "query_param",
  "id_param_name": "document_id"
}
```

**Examples**:
- `/api/documents?document_id=123` → Resource ID: `123`
- `/api/view?file_id=abc&format=pdf` → Resource ID: `abc` (if `id_param_name` is `file_id`)

**Best for**: APIs where resource ID is passed as a query parameter

#### Option 3: Header

Extracts the resource ID from an HTTP header.

```json
{
  "id_location": "header",
  "id_param_name": "X-Resource-ID"
}
```

**Example request**:
```bash
curl -H "X-Resource-ID: 123" http://api.example.com/documents
```

**Best for**: Special cases where resource ID is passed in headers

## Relation Mapping

The `relation_mapping` parameter maps HTTP methods to OpenFGA relations.

### Default Mapping

If not specified, the plugin uses these defaults:

```json
{
  "relation_mapping": {
    "GET": "reader",
    "POST": "writer",
    "PUT": "writer",
    "PATCH": "writer",
    "DELETE": "admin"
  }
}
```

### Custom Mapping

You can override the defaults to match your authorization model:

```json
{
  "relation_mapping": {
    "GET": "viewer",
    "POST": "editor",
    "PUT": "editor",
    "PATCH": "editor",
    "DELETE": "owner"
  }
}
```

### Examples Based on Use Cases

#### Document Management System

```json
{
  "relation_mapping": {
    "GET": "can_view",
    "POST": "can_create",
    "PUT": "can_edit",
    "DELETE": "can_delete"
  }
}
```

#### Simple Read/Write System

```json
{
  "relation_mapping": {
    "GET": "read",
    "POST": "write",
    "PUT": "write",
    "PATCH": "write",
    "DELETE": "write"
  }
}
```

## Caching Configuration

### Understanding Cache Behavior

The plugin uses an LRU (Least Recently Used) cache with the following characteristics:

- **Cache Key Format**: `{user}:{resource_type}:{resource_id}:{relation}`
- **Cache Size**: 200 entries (hardcoded in current version)
- **Eviction**: Least recently used entries are removed when cache is full

### Cache TTL Strategies

#### Short TTL (60-300 seconds)

```json
{
  "cache_ttl": 120
}
```

**Use when**:
- Permissions change frequently
- Real-time permission updates are critical
- Resource access patterns are highly dynamic

#### Medium TTL (300-1800 seconds)

```json
{
  "cache_ttl": 600
}
```

**Use when**:
- Standard business applications
- Permissions change occasionally
- Balance between performance and freshness

#### Long TTL (1800+ seconds)

```json
{
  "cache_ttl": 3600
}
```

**Use when**:
- Permissions rarely change
- Performance is critical
- Eventually consistent authorization is acceptable

#### No Cache

```json
{
  "cache_ttl": 0
}
```

**Use when**:
- Every authorization decision must be fresh
- Testing or debugging
- Compliance requires no caching

## Security Settings

### SSL/TLS Configuration

Always use SSL in production:

```json
{
  "openfga_url": "https://api.fga.example.com",
  "ssl_verify": true
}
```

For development with self-signed certificates:

```json
{
  "openfga_url": "https://localhost:8080",
  "ssl_verify": false
}
```

### Network Security

- Deploy OpenFGA in the same network/VPC as APISIX
- Use private networking when possible
- Implement network policies to restrict access

## Complete Examples

### Example 1: Document Management API

```json
{
  "uri": "/api/documents/*",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://fga.internal.company.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "authorization_model_id": "01HYYYYYYYYYYYYYYYYYYY",
      "user_header": "X-User-ID",
      "resource_type": "document",
      "relation_mapping": {
        "GET": "viewer",
        "POST": "editor",
        "PUT": "editor",
        "DELETE": "owner"
      },
      "id_location": "last_path_segment",
      "cache_ttl": 300,
      "timeout": 3000,
      "ssl_verify": true
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "document-service:8080": 1
    }
  }
}
```

**Usage**:
```bash
# View document
curl -H "X-User-ID: user:alice" http://api.example.com/api/documents/123

# Edit document
curl -X PUT -H "X-User-ID: user:alice" http://api.example.com/api/documents/123

# Delete document (requires owner)
curl -X DELETE -H "X-User-ID: user:alice" http://api.example.com/api/documents/123
```

### Example 2: File Sharing with Query Parameters

```json
{
  "uri": "/api/files/download",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://fga.example.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "file",
      "id_location": "query_param",
      "id_param_name": "file_id",
      "relation_mapping": {
        "GET": "can_download"
      },
      "cache_ttl": 600
    }
  }
}
```

**Usage**:
```bash
curl -H "X-User-ID: user:bob" \
  "http://api.example.com/api/files/download?file_id=abc-123"
```

### Example 3: Multi-Tenant API

```json
{
  "uri": "/api/tenants/*/resources/*",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://fga.example.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "resource",
      "user_header": "X-Subject",
      "id_location": "last_path_segment",
      "cache_ttl": 300
    }
  }
}
```

### Example 4: Development/Testing Configuration

```json
{
  "uri": "/api/test/*",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "http://localhost:8080",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "test_resource",
      "cache_ttl": 0,
      "ssl_verify": false,
      "timeout": 5000
    }
  }
}
```

## Configuration via Admin API

### Add Plugin to Route

```bash
curl http://127.0.0.1:9180/apisix/admin/routes/1 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '
{
  "uri": "/api/documents/*",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://fga.example.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "document"
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

### Update Plugin Configuration

```bash
curl http://127.0.0.1:9180/apisix/admin/routes/1 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PATCH -d '
{
  "plugins": {
    "openfga-authz": {
      "cache_ttl": 600
    }
  }
}'
```

### Remove Plugin from Route

```bash
curl http://127.0.0.1:9180/apisix/admin/routes/1 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PATCH -d '
{
  "plugins": {
    "openfga-authz": null
  }
}'
```

## Validation

The plugin validates configuration at startup and when updated. Common validation errors:

### Missing Required Fields

```
error: property "openfga_url" is required
```

**Solution**: Add the required parameter

### Invalid Type

```
error: property "cache_ttl" validation failed: wrong type: expected integer, got string
```

**Solution**: Use correct type (e.g., `300` instead of `"300"`)

### Invalid Enum Value

```
error: property "id_location" validation failed: value should be one of: last_path_segment, query_param, header
```

**Solution**: Use one of the allowed values

## Best Practices

1. **Use specific authorization model IDs** in production to prevent unexpected behavior from model updates
2. **Set appropriate cache TTL** based on your permission change frequency
3. **Use SSL/TLS** in production environments
4. **Monitor timeout values** and adjust based on OpenFGA performance
5. **Test configuration** in development environment before deploying to production
6. **Document your relation mappings** to match your OpenFGA authorization model
7. **Use meaningful resource types** that match your domain model

## Troubleshooting Configuration

### Plugin Not Loading

- Check APISIX error logs: `/usr/local/apisix/logs/error.log`
- Verify plugin is listed in `config.yaml`
- Ensure Lua file is in correct directory

### Configuration Rejected

- Validate JSON syntax
- Check all required fields are present
- Verify field types match schema

### Runtime Errors

- Check OpenFGA URL is accessible from APISIX
- Verify store_id exists in OpenFGA
- Ensure authorization_model_id is valid (if specified)

For more examples, see the [examples](../examples/) directory.
