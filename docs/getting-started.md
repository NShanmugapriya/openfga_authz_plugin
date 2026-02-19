# Getting Started with OpenFGA Authorization Plugin

This guide will help you get started with the OpenFGA Authorization Plugin for Apache APISIX.

## Prerequisites

- Docker and Docker Compose installed
- Basic understanding of Apache APISIX
- Basic understanding of OpenFGA concepts

## Quick Start with Docker

### 1. Clone the Repository

```bash
git clone https://github.com/NShanmugapriya/openfga_authz_plugin.git
cd openfga_authz_plugin
```

### 2. Start Services

```bash
docker-compose up -d
```

This starts:
- OpenFGA server on port 8080
- Apache APISIX on port 9080 (gateway) and 9180 (admin)
- etcd for APISIX configuration
- httpbin as a sample upstream service

### 3. Verify Services

```bash
# Check OpenFGA
curl http://localhost:8080/healthz

# Check APISIX
curl http://localhost:9080
```

### 4. Create OpenFGA Store and Model

First, create a store:

```bash
curl -X POST http://localhost:8080/stores \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-store"
  }'
```

This returns a store ID like `01HXXXXXXXXXXXXXXXXXXX`. Save this for later.

Next, create an authorization model:

```bash
curl -X POST http://localhost:8080/stores/{STORE_ID}/authorization-models \
  -H "Content-Type: application/json" \
  -d '{
    "schema_version": "1.1",
    "type_definitions": [
      {
        "type": "user"
      },
      {
        "type": "document",
        "relations": {
          "owner": {
            "this": {}
          },
          "editor": {
            "union": {
              "child": [
                {"this": {}},
                {"computedUserset": {"relation": "owner"}}
              ]
            }
          },
          "viewer": {
            "union": {
              "child": [
                {"this": {}},
                {"computedUserset": {"relation": "editor"}}
              ]
            }
          }
        },
        "metadata": {
          "relations": {
            "owner": {"directly_related_user_types": [{"type": "user"}]},
            "editor": {"directly_related_user_types": [{"type": "user"}]},
            "viewer": {"directly_related_user_types": [{"type": "user"}]}
          }
        }
      }
    ]
  }'
```

Save the returned authorization model ID.

### 5. Add Some Tuples

Create some relationships:

```bash
# Alice is owner of document 123
curl -X POST http://localhost:8080/stores/{STORE_ID}/write \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [
        {
          "user": "user:alice",
          "relation": "owner",
          "object": "document:123"
        },
        {
          "user": "user:bob",
          "relation": "editor",
          "object": "document:123"
        },
        {
          "user": "user:charlie",
          "relation": "viewer",
          "object": "document:123"
        }
      ]
    }
  }'
```

### 6. Configure APISIX Route

Create a route with the plugin:

```bash
curl http://127.0.0.1:9180/apisix/admin/routes/1 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '
{
  "uri": "/api/documents/*",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "http://openfga:8080",
      "store_id": "{YOUR_STORE_ID}",
      "authorization_model_id": "{YOUR_MODEL_ID}",
      "resource_type": "document",
      "user_header": "X-User-ID",
      "relation_mapping": {
        "GET": "viewer",
        "PUT": "editor",
        "DELETE": "owner"
      },
      "ssl_verify": false
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "httpbin:80": 1
    }
  }
}'
```

Replace `{YOUR_STORE_ID}` and `{YOUR_MODEL_ID}` with the values from steps 4.

### 7. Test the Authorization

```bash
# Alice (owner) can view, edit, and delete
curl -v -H "X-User-ID: user:alice" \
  http://localhost:9080/api/documents/123
# Should return 200 OK

curl -v -X PUT -H "X-User-ID: user:alice" \
  http://localhost:9080/api/documents/123
# Should return 200 OK

curl -v -X DELETE -H "X-User-ID: user:alice" \
  http://localhost:9080/api/documents/123
# Should return 200 OK

# Bob (editor) can view and edit, but not delete
curl -v -H "X-User-ID: user:bob" \
  http://localhost:9080/api/documents/123
# Should return 200 OK

curl -v -X PUT -H "X-User-ID: user:bob" \
  http://localhost:9080/api/documents/123
# Should return 200 OK

curl -v -X DELETE -H "X-User-ID: user:bob" \
  http://localhost:9080/api/documents/123
# Should return 403 Forbidden

# Charlie (viewer) can only view
curl -v -H "X-User-ID: user:charlie" \
  http://localhost:9080/api/documents/123
# Should return 200 OK

curl -v -X PUT -H "X-User-ID: user:charlie" \
  http://localhost:9080/api/documents/123
# Should return 403 Forbidden

# Unknown user has no access
curl -v -H "X-User-ID: user:eve" \
  http://localhost:9080/api/documents/123
# Should return 403 Forbidden
```

### 8. Check Logs

View APISIX logs to see authorization decisions:

```bash
docker logs apisix 2>&1 | grep -i openfga
```

You should see log entries showing authorization checks and results.

## Manual Installation (Without Docker)

### 1. Install Apache APISIX

Follow the [official APISIX installation guide](https://apisix.apache.org/docs/apisix/installation-guide/).

### 2. Install OpenFGA

Follow the [official OpenFGA installation guide](https://openfga.dev/docs/getting-started/setup-openfga).

### 3. Copy Plugin File

```bash
cp apisix/plugins/openfga-authz.lua /path/to/apisix/apisix/plugins/
```

### 4. Update APISIX Configuration

Edit `/path/to/apisix/conf/config.yaml` and add the plugin:

```yaml
plugins:
  - ... # other plugins
  - openfga-authz
```

### 5. Reload APISIX

```bash
apisix reload
```

### 6. Configure Routes

Use the APISIX Admin API or configuration files to set up routes with the plugin (see step 6 in Docker section).

## Next Steps

- Read the [Configuration Guide](configuration.md) for detailed configuration options
- Explore [Examples](../examples/) for different use cases
- Learn about [Performance Tuning](configuration.md#performance-considerations)
- Check the [README](../README.md) for more information

## Troubleshooting

### Plugin Not Loading

**Symptom**: Plugin configuration rejected or not found

**Solutions**:
1. Verify plugin file is in correct location
2. Check plugin is listed in `config.yaml`
3. Review APISIX error logs
4. Ensure APISIX was reloaded after adding the plugin

### OpenFGA Connection Failed

**Symptom**: 500 Internal Server Error, logs show "OpenFGA request failed"

**Solutions**:
1. Verify OpenFGA URL is correct and accessible from APISIX
2. Check OpenFGA is running: `curl http://localhost:8080/healthz`
3. For Docker: Ensure services are on the same network
4. Check firewall rules

### Authorization Always Denied

**Symptom**: 403 Forbidden for all requests

**Solutions**:
1. Verify tuples exist in OpenFGA
2. Check store_id and authorization_model_id are correct
3. Ensure user identifier format matches tuples (e.g., `user:alice`)
4. Verify relation mapping matches your model
5. Check resource ID extraction is working (review logs)

### User Header Not Found

**Symptom**: 401 Unauthorized, "User header not found"

**Solutions**:
1. Ensure `X-User-ID` header (or configured header) is sent
2. Check authentication is happening before authorization
3. Verify header name matches configuration

## Support

- [GitHub Issues](https://github.com/NShanmugapriya/openfga_authz_plugin/issues)
- [GitHub Discussions](https://github.com/NShanmugapriya/openfga_authz_plugin/discussions)
- [APISIX Documentation](https://apisix.apache.org/docs/)
- [OpenFGA Documentation](https://openfga.dev/docs/)

## Cleaning Up

To stop and remove all Docker containers:

```bash
docker-compose down -v
```

This removes containers and volumes, cleaning up all data.
