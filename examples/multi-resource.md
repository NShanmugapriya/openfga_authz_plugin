# Multi-Resource Configuration Example

This example shows how to configure the OpenFGA authorization plugin for multiple resource types in a single application.

## Scenario

An application with multiple protected resources:
1. **Documents**: User-created content
2. **Folders**: Organizational containers
3. **Projects**: Top-level workspaces

Each resource type has its own access patterns and permissions.

## OpenFGA Authorization Model

```typescript
model
  schema 1.1

type user

type organization
  relations
    define member: [user]
    define admin: [user]

type project
  relations
    define owner: [user, organization#member]
    define editor: [user] or owner
    define viewer: [user] or editor
    define parent: [organization]

type folder
  relations
    define owner: [user]
    define editor: [user] or owner
    define viewer: [user] or editor
    define parent: [project]

type document
  relations
    define owner: [user]
    define editor: [user] or owner
    define viewer: [user] or editor
    define parent: [folder]
```

## APISIX Configuration

### Route 1: Documents

```bash
curl http://127.0.0.1:9180/apisix/admin/routes/1 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '
{
  "uri": "/api/documents/*",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://api.fga.example.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "document",
      "relation_mapping": {
        "GET": "viewer",
        "POST": "editor",
        "PUT": "editor",
        "DELETE": "owner"
      },
      "cache_ttl": 300
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "document-service:8080": 1
    }
  }
}'
```

### Route 2: Folders

```bash
curl http://127.0.0.1:9180/apisix/admin/routes/2 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '
{
  "uri": "/api/folders/*",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://api.fga.example.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "folder",
      "relation_mapping": {
        "GET": "viewer",
        "POST": "editor",
        "PUT": "editor",
        "DELETE": "owner"
      },
      "cache_ttl": 300
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "folder-service:8080": 1
    }
  }
}'
```

### Route 3: Projects

```bash
curl http://127.0.0.1:9180/apisix/admin/routes/3 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '
{
  "uri": "/api/projects/*",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://api.fga.example.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "project",
      "relation_mapping": {
        "GET": "viewer",
        "POST": "editor",
        "PUT": "editor",
        "DELETE": "owner"
      },
      "cache_ttl": 600
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "project-service:8080": 1
    }
  }
}'
```

## Sample Tuples

```json
[
  {
    "user": "user:alice",
    "relation": "owner",
    "object": "project:proj1"
  },
  {
    "user": "user:bob",
    "relation": "editor",
    "object": "project:proj1"
  },
  {
    "user": "user:alice",
    "relation": "owner",
    "object": "folder:folder1"
  },
  {
    "user": "folder:folder1",
    "relation": "parent",
    "object": "project:proj1"
  },
  {
    "user": "user:alice",
    "relation": "owner",
    "object": "document:doc1"
  },
  {
    "user": "document:doc1",
    "relation": "parent",
    "object": "folder:folder1"
  }
]
```

## Testing

### Access Project

```bash
# Alice can access her project
curl -H "X-User-ID: user:alice" \
  http://localhost:9080/api/projects/proj1

# Bob can view (as editor has viewer)
curl -H "X-User-ID: user:bob" \
  http://localhost:9080/api/projects/proj1

# Charlie cannot access
curl -H "X-User-ID: user:charlie" \
  http://localhost:9080/api/projects/proj1
# Returns 403 Forbidden
```

### Access Folder

```bash
# Alice can access her folder
curl -H "X-User-ID: user:alice" \
  http://localhost:9080/api/folders/folder1

# Bob cannot directly access folder (no direct relation)
curl -H "X-User-ID: user:bob" \
  http://localhost:9080/api/folders/folder1
# Returns 403 Forbidden
```

### Access Document

```bash
# Alice can access her document
curl -H "X-User-ID: user:alice" \
  http://localhost:9080/api/documents/doc1

# Bob cannot access document
curl -H "X-User-ID: user:bob" \
  http://localhost:9080/api/documents/doc1
# Returns 403 Forbidden
```

## Configuration via YAML

For static configuration, you can define routes in `apisix.yaml`:

```yaml
routes:
  - uri: /api/documents/*
    plugins:
      openfga-authz:
        openfga_url: https://api.fga.example.com
        store_id: "01HXXXXXXXXXXXXXXXXXXX"
        resource_type: document
        relation_mapping:
          GET: viewer
          POST: editor
          PUT: editor
          DELETE: owner
        cache_ttl: 300
    upstream:
      type: roundrobin
      nodes:
        document-service:8080: 1

  - uri: /api/folders/*
    plugins:
      openfga-authz:
        openfga_url: https://api.fga.example.com
        store_id: "01HXXXXXXXXXXXXXXXXXXX"
        resource_type: folder
        relation_mapping:
          GET: viewer
          POST: editor
          PUT: editor
          DELETE: owner
        cache_ttl: 300
    upstream:
      type: roundrobin
      nodes:
        folder-service:8080: 1

  - uri: /api/projects/*
    plugins:
      openfga-authz:
        openfga_url: https://api.fga.example.com
        store_id: "01HXXXXXXXXXXXXXXXXXXX"
        resource_type: project
        relation_mapping:
          GET: viewer
          POST: editor
          PUT: editor
          DELETE: owner
        cache_ttl: 600
    upstream:
      type: roundrobin
      nodes:
        project-service:8080: 1
```

## Benefits

1. **Centralized Authorization**: All resources protected by OpenFGA
2. **Consistent Security**: Same authorization patterns across resources
3. **Easy Maintenance**: Update permissions in OpenFGA, not code
4. **Resource Isolation**: Each resource type independently configured
5. **Flexible Caching**: Different TTLs for different resource types

## Performance Considerations

### Cache TTL Strategy

- **Projects**: 600s (10 min) - Permissions change less frequently
- **Folders**: 300s (5 min) - Standard TTL
- **Documents**: 300s (5 min) - Standard TTL

Adjust based on your permission change patterns.

### Cache Key Space

With 3 resource types and multiple users:
- Documents: `user:alice:document:doc1:viewer`
- Folders: `user:alice:folder:folder1:owner`
- Projects: `user:bob:project:proj1:editor`

Each unique combination is cached separately.

## Wildcard Routes

You can also use wildcard routes with path variables:

```bash
curl http://127.0.0.1:9180/apisix/admin/routes/4 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '
{
  "uri": "/api/projects/*/documents/*",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://api.fga.example.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "document",
      "id_location": "last_path_segment"
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "document-service:8080": 1
    }
  }
}'
```

Request: `GET /api/projects/proj1/documents/doc1`
- Extracts resource ID: `doc1`
- Checks: `user:alice` has `viewer` on `document:doc1`

## Summary

This example demonstrates:
- ✅ Multiple resource types in one application
- ✅ Consistent authorization pattern across resources
- ✅ Different cache strategies per resource type
- ✅ Hierarchical resource relationships
- ✅ Flexible route configuration

## Next Steps

- Explore [Custom Relation Mapping](custom-relations.md)
- Read the [Configuration Guide](../docs/configuration.md)
- Review [Architecture Documentation](../docs/architecture.md) for performance considerations
