# Quick Reference Guide

Quick reference for common tasks and configurations.

## Installation

```bash
# Clone repository
git clone https://github.com/NShanmugapriya/openfga_authz_plugin.git
cd openfga_authz_plugin

# Start with Docker
docker-compose up -d

# Setup OpenFGA
bash scripts/setup-openfga.sh
```

## Basic Configuration

```bash
curl http://127.0.0.1:9180/apisix/admin/routes/1 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '{
  "uri": "/api/documents/*",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "http://openfga:8080",
      "store_id": "YOUR_STORE_ID",
      "resource_type": "document"
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {"httpbin:80": 1}
  }
}'
```

## Common Commands

```bash
# Start services
make start

# Stop services
make stop

# View logs
make logs

# Run tests
make test

# Lint code
make lint

# Clean up
make clean
```

## Testing Requests

```bash
# Test authorized access
curl -H "X-User-ID: user:alice" \
  http://localhost:9080/api/documents/123

# Test unauthorized access
curl -H "X-User-ID: user:eve" \
  http://localhost:9080/api/documents/123

# Test without user header
curl http://localhost:9080/api/documents/123
```

## Configuration Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `openfga_url` | Yes | - | OpenFGA server URL |
| `store_id` | Yes | - | OpenFGA store ID |
| `resource_type` | Yes | - | Resource type name |
| `user_header` | No | `X-User-ID` | Header with user ID |
| `cache_ttl` | No | `300` | Cache TTL in seconds |
| `timeout` | No | `3000` | Request timeout (ms) |

## Relation Mapping Examples

### Default Mapping
```json
{
  "GET": "reader",
  "POST": "writer",
  "PUT": "writer",
  "DELETE": "admin"
}
```

### Custom Mapping
```json
{
  "relation_mapping": {
    "GET": "viewer",
    "POST": "editor",
    "PUT": "editor",
    "DELETE": "owner"
  }
}
```

## Resource ID Extraction

### From Path (Default)
```json
{
  "id_location": "last_path_segment"
}
```
URL: `/api/documents/123` → ID: `123`

### From Query Parameter
```json
{
  "id_location": "query_param",
  "id_param_name": "doc_id"
}
```
URL: `/api/documents?doc_id=123` → ID: `123`

### From Header
```json
{
  "id_location": "header",
  "id_param_name": "X-Resource-ID"
}
```
Header: `X-Resource-ID: 123` → ID: `123`

## OpenFGA Quick Reference

### Create Store
```bash
curl -X POST http://localhost:8080/stores \
  -H "Content-Type: application/json" \
  -d '{"name": "my-store"}'
```

### Add Tuple
```bash
curl -X POST http://localhost:8080/stores/{STORE_ID}/write \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [{
        "user": "user:alice",
        "relation": "owner",
        "object": "document:123"
      }]
    }
  }'
```

### Check Permission
```bash
curl -X POST http://localhost:8080/stores/{STORE_ID}/check \
  -H "Content-Type: application/json" \
  -d '{
    "tuple_key": {
      "user": "user:alice",
      "relation": "viewer",
      "object": "document:123"
    }
  }'
```

## Common Issues

### "User header not found"
- Add `X-User-ID` header to request
- Or configure custom `user_header`

### "Resource ID not found"
- Check `id_location` setting
- Verify resource ID is in expected location

### "OpenFGA request failed"
- Verify `openfga_url` is correct
- Check OpenFGA is running
- Test network connectivity

### High latency
- Enable caching: `cache_ttl: 300`
- Check network to OpenFGA
- Verify OpenFGA performance

## HTTP Status Codes

| Code | Meaning | Reason |
|------|---------|--------|
| 200 | OK | Authorized, request forwarded |
| 400 | Bad Request | Resource ID not found |
| 401 | Unauthorized | User header missing |
| 403 | Forbidden | Access denied by OpenFGA |
| 500 | Internal Error | OpenFGA error or config issue |

## Environment Variables

```bash
# For setup script
export OPENFGA_URL=http://localhost:8080

# For APISIX Admin API
export APISIX_ADMIN_KEY=edd1c9f034335f136f87ad84b625c8f1
```

## Links

- [Full Documentation](README.md)
- [Configuration Guide](docs/configuration.md)
- [Getting Started](docs/getting-started.md)
- [Architecture](docs/architecture.md)
- [Examples](examples/)

## Support

- [GitHub Issues](https://github.com/NShanmugapriya/openfga_authz_plugin/issues)
- [APISIX Docs](https://apisix.apache.org/docs/)
- [OpenFGA Docs](https://openfga.dev/docs/)
