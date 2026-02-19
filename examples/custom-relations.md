# Custom Relation Mapping Example

This example demonstrates advanced relation mapping configurations for different use cases.

## Overview

The `relation_mapping` configuration allows you to map HTTP methods to OpenFGA relations. This enables flexible authorization patterns that match your business logic.

## Example 1: Healthcare Record System

### Scenario

A healthcare system where:
- Doctors can read and write medical records
- Nurses can read records
- Patients can only view their own records
- Admins can do everything

### OpenFGA Model

```typescript
model
  schema 1.1

type user

type medical_record
  relations
    define patient: [user]
    define nurse: [user]
    define doctor: [user]
    define admin: [user]
    define can_view: patient or nurse or doctor or admin
    define can_edit: doctor or admin
    define can_delete: admin
```

### APISIX Configuration

```bash
curl http://127.0.0.1:9180/apisix/admin/routes/1 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '
{
  "uri": "/api/medical-records/*",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://api.fga.example.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "medical_record",
      "user_header": "X-User-ID",
      "relation_mapping": {
        "GET": "can_view",
        "POST": "can_edit",
        "PUT": "can_edit",
        "PATCH": "can_edit",
        "DELETE": "can_delete"
      },
      "cache_ttl": 60
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "medical-records-service:8080": 1
    }
  }
}'
```

### Testing

```bash
# Doctor can view and edit
curl -H "X-User-ID: user:doctor_smith" \
  http://localhost:9080/api/medical-records/12345

curl -X PUT -H "X-User-ID: user:doctor_smith" \
  -d '{"diagnosis": "..."}' \
  http://localhost:9080/api/medical-records/12345

# Nurse can only view
curl -H "X-User-ID: user:nurse_jones" \
  http://localhost:9080/api/medical-records/12345

curl -X PUT -H "X-User-ID: user:nurse_jones" \
  -d '{"notes": "..."}' \
  http://localhost:9080/api/medical-records/12345
# Returns 403 Forbidden

# Patient can view their own record
curl -H "X-User-ID: user:patient_alice" \
  http://localhost:9080/api/medical-records/12345

# Only admin can delete
curl -X DELETE -H "X-User-ID: user:admin_bob" \
  http://localhost:9080/api/medical-records/12345
```

## Example 2: Content Management System

### Scenario

A CMS where content goes through states:
- **Draft**: Author can edit
- **Review**: Editor can edit and publish
- **Published**: Public can read, editor can unpublish

### OpenFGA Model

```typescript
model
  schema 1.1

type user

type article
  relations
    define author: [user]
    define editor: [user]
    define can_read: [user:*] or author or editor
    define can_draft: author
    define can_edit: author or editor
    define can_publish: editor
    define can_unpublish: editor
```

### APISIX Configuration

```bash
curl http://127.0.0.1:9180/apisix/admin/routes/1 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '
{
  "uri": "/api/articles/*",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://api.fga.example.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "article",
      "relation_mapping": {
        "GET": "can_read",
        "POST": "can_draft",
        "PUT": "can_edit",
        "PATCH": "can_edit"
      },
      "cache_ttl": 300
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "cms-service:8080": 1
    }
  }
}'
```

For publish/unpublish actions, use separate routes:

```bash
# Publish route
curl http://127.0.0.1:9180/apisix/admin/routes/2 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '
{
  "uri": "/api/articles/*/publish",
  "methods": ["POST"],
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://api.fga.example.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "article",
      "relation_mapping": {
        "POST": "can_publish"
      },
      "id_location": "last_path_segment"
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "cms-service:8080": 1
    }
  }
}'
```

## Example 3: API with Read-Only and Admin Endpoints

### Scenario

An API with two types of operations:
- Read operations (GET): Any authenticated user
- Write operations (POST, PUT, DELETE): Only admins

### OpenFGA Model

```typescript
model
  schema 1.1

type user

type api_resource
  relations
    define user: [user]
    define admin: [user]
    define can_read: user or admin
    define can_write: admin
```

### APISIX Configuration

```bash
curl http://127.0.0.1:9180/apisix/admin/routes/1 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '
{
  "uri": "/api/resources/*",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://api.fga.example.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "api_resource",
      "relation_mapping": {
        "GET": "can_read",
        "POST": "can_write",
        "PUT": "can_write",
        "PATCH": "can_write",
        "DELETE": "can_write"
      }
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "api-service:8080": 1
    }
  }
}'
```

## Example 4: Granular CRUD Operations

### Scenario

Different permissions for different operations:
- Create: Writers
- Read: Readers (includes writers and admins)
- Update: Writers
- Delete: Admins only

### OpenFGA Model

```typescript
model
  schema 1.1

type user

type resource
  relations
    define admin: [user]
    define writer: [user] or admin
    define reader: [user] or writer
    define can_create: writer
    define can_read: reader
    define can_update: writer
    define can_delete: admin
```

### APISIX Configuration

```bash
curl http://127.0.0.1:9180/apisix/admin/routes/1 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '
{
  "uri": "/api/resources/*",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://api.fga.example.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "resource",
      "relation_mapping": {
        "GET": "can_read",
        "POST": "can_create",
        "PUT": "can_update",
        "PATCH": "can_update",
        "DELETE": "can_delete"
      }
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "resource-service:8080": 1
    }
  }
}'
```

## Example 5: File Sharing with Download/Upload

### Scenario

File sharing platform where:
- Download requires read permission
- Upload requires write permission
- Delete requires ownership

### OpenFGA Model

```typescript
model
  schema 1.1

type user

type file
  relations
    define owner: [user]
    define contributor: [user] or owner
    define viewer: [user] or contributor
    define can_download: viewer
    define can_upload: contributor
    define can_delete: owner
```

### APISIX Configuration

```bash
# Download endpoint
curl http://127.0.0.1:9180/apisix/admin/routes/1 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '
{
  "uri": "/api/files/*/download",
  "methods": ["GET"],
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://api.fga.example.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "file",
      "relation_mapping": {
        "GET": "can_download"
      },
      "id_location": "query_param",
      "id_param_name": "file_id"
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "file-service:8080": 1
    }
  }
}'

# Upload endpoint
curl http://127.0.0.1:9180/apisix/admin/routes/2 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '
{
  "uri": "/api/files/*/upload",
  "methods": ["POST", "PUT"],
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://api.fga.example.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "file",
      "relation_mapping": {
        "POST": "can_upload",
        "PUT": "can_upload"
      }
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "file-service:8080": 1
    }
  }
}'

# Delete endpoint
curl http://127.0.0.1:9180/apisix/admin/routes/3 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '
{
  "uri": "/api/files/*",
  "methods": ["DELETE"],
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://api.fga.example.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "file",
      "relation_mapping": {
        "DELETE": "can_delete"
      }
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "file-service:8080": 1
    }
  }
}'
```

## Example 6: Custom HTTP Methods

### Scenario

API using custom HTTP methods or actions:

### APISIX Configuration

```bash
curl http://127.0.0.1:9180/apisix/admin/routes/1 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '
{
  "uri": "/api/workflows/*",
  "plugins": {
    "openfga-authz": {
      "openfga_url": "https://api.fga.example.com",
      "store_id": "01HXXXXXXXXXXXXXXXXXXX",
      "resource_type": "workflow",
      "relation_mapping": {
        "GET": "can_view",
        "POST": "can_execute",
        "PUT": "can_modify",
        "PATCH": "can_modify",
        "DELETE": "can_delete"
      }
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "workflow-service:8080": 1
    }
  }
}'
```

## Best Practices

### 1. Match Your Domain Model

Design relations that match your business logic:

```json
{
  "relation_mapping": {
    "GET": "can_view_report",
    "POST": "can_generate_report",
    "PUT": "can_modify_report",
    "DELETE": "can_archive_report"
  }
}
```

### 2. Use Consistent Naming

Use consistent relation names across your models:
- `can_view`, `can_edit`, `can_delete`
- `viewer`, `editor`, `owner`
- `read`, `write`, `admin`

Pick one pattern and stick with it.

### 3. Leverage Relation Inheritance

Use OpenFGA's relation inheritance to reduce duplication:

```typescript
type document
  relations
    define owner: [user]
    define editor: [user] or owner
    define viewer: [user] or editor
```

Now `owner` automatically has `editor` and `viewer` permissions.

### 4. Consider Caching Impact

For frequently changing permissions, use shorter cache TTL:

```json
{
  "cache_ttl": 60,
  "relation_mapping": {
    "GET": "can_access"
  }
}
```

### 5. Document Your Mappings

Create documentation for your team:

```markdown
## Permission Mappings

| HTTP Method | Relation | Who Has Access |
|-------------|----------|----------------|
| GET | can_view | Viewers, Editors, Owners |
| POST | can_create | Editors, Owners |
| PUT | can_edit | Editors, Owners |
| DELETE | can_delete | Owners only |
```

## Troubleshooting

### Wrong Relation Used

**Problem**: Authorization fails even though user has correct permission

**Solution**: Check that relation mapping matches your OpenFGA model

```bash
# Check APISIX logs
tail -f /usr/local/apisix/logs/error.log

# Look for:
# [info] ... Checking authorization for ... relation=<RELATION>
```

Ensure `<RELATION>` matches what's defined in your OpenFGA model.

### Unmapped HTTP Method

**Problem**: Some HTTP method not working

**Solution**: Add mapping for that method:

```json
{
  "relation_mapping": {
    "GET": "reader",
    "HEAD": "reader",
    "OPTIONS": "reader"
  }
}
```

Or use the default mappings by omitting `relation_mapping`.

## Summary

Custom relation mapping enables:
- ✅ Fine-grained control over permissions
- ✅ Business logic alignment
- ✅ Flexible authorization patterns
- ✅ Support for domain-specific operations
- ✅ Clear separation of concerns

## Next Steps

- Review [Basic Document Authorization](basic-document-authz.md)
- Explore [Multi-Resource Configuration](multi-resource.md)
- Read the [Configuration Guide](../docs/configuration.md)
