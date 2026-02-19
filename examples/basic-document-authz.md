# Basic Document Authorization Example

This example demonstrates a simple document management system with fine-grained access control using OpenFGA and Apache APISIX.

## Scenario

You have a document management API where users can:
- View documents (GET)
- Edit documents (PUT)
- Delete documents (DELETE)

Authorization is based on OpenFGA relations.

## OpenFGA Authorization Model

```typescript
model
  schema 1.1

type user

type document
  relations
    define viewer: [user]
    define editor: [user] or viewer
    define owner: [user] or editor
```

## Tuples in OpenFGA

Example tuples for this scenario:

```json
[
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
```

## APISIX Route Configuration

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
      "authorization_model_id": "01HYYYYYYYYYYYYYYYYYYY",
      "user_header": "X-User-ID",
      "resource_type": "document",
      "relation_mapping": {
        "GET": "viewer",
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
      "document-service.internal:8080": 1
    }
  }
}'
```

## Testing

### Test 1: Alice (Owner) Can Do Everything

```bash
# View document - SUCCESS
curl -H "X-User-ID: user:alice" \
  http://localhost:9080/api/documents/123

# Edit document - SUCCESS
curl -X PUT \
  -H "X-User-ID: user:alice" \
  -H "Content-Type: application/json" \
  -d '{"title": "Updated Document"}' \
  http://localhost:9080/api/documents/123

# Delete document - SUCCESS
curl -X DELETE \
  -H "X-User-ID: user:alice" \
  http://localhost:9080/api/documents/123
```

### Test 2: Bob (Editor) Can View and Edit

```bash
# View document - SUCCESS
curl -H "X-User-ID: user:bob" \
  http://localhost:9080/api/documents/123

# Edit document - SUCCESS
curl -X PUT \
  -H "X-User-ID: user:bob" \
  -H "Content-Type: application/json" \
  -d '{"title": "Updated by Bob"}' \
  http://localhost:9080/api/documents/123

# Delete document - FORBIDDEN (403)
curl -X DELETE \
  -H "X-User-ID: user:bob" \
  http://localhost:9080/api/documents/123
```

Expected response for forbidden action:
```json
{
  "message": "Forbidden: Access denied"
}
```

### Test 3: Charlie (Viewer) Can Only View

```bash
# View document - SUCCESS
curl -H "X-User-ID: user:charlie" \
  http://localhost:9080/api/documents/123

# Edit document - FORBIDDEN (403)
curl -X PUT \
  -H "X-User-ID: user:charlie" \
  -H "Content-Type: application/json" \
  -d '{"title": "Attempt to update"}' \
  http://localhost:9080/api/documents/123

# Delete document - FORBIDDEN (403)
curl -X DELETE \
  -H "X-User-ID: user:charlie" \
  http://localhost:9080/api/documents/123
```

### Test 4: Unknown User Has No Access

```bash
# View document - FORBIDDEN (403)
curl -H "X-User-ID: user:eve" \
  http://localhost:9080/api/documents/123
```

### Test 5: Missing User Header

```bash
# No user header - UNAUTHORIZED (401)
curl http://localhost:9080/api/documents/123
```

Expected response:
```json
{
  "message": "Unauthorized: User header not found"
}
```

## Expected Behavior

| User | GET | PUT | DELETE |
|------|-----|-----|--------|
| alice (owner) | ✅ | ✅ | ✅ |
| bob (editor) | ✅ | ✅ | ❌ |
| charlie (viewer) | ✅ | ❌ | ❌ |
| eve (no access) | ❌ | ❌ | ❌ |

## Monitoring

Check APISIX logs for authorization decisions:

```bash
tail -f /usr/local/apisix/logs/error.log
```

You should see log entries like:

```
[info] ... Checking authorization for user=user:alice resource=document:123 relation=viewer
[info] ... OpenFGA check response: allowed=true
[info] ... Access granted for user=user:alice resource=document:123 relation=viewer
```

Or for denied access:

```
[info] ... Checking authorization for user=user:charlie resource=document:123 relation=editor
[info] ... OpenFGA check response: allowed=false
[warn] ... Access denied for user=user:charlie resource=document:123 relation=editor
```

## Advanced: Adding Tuples via OpenFGA API

To grant user `dave` viewer access to document 123:

```bash
curl -X POST https://api.fga.example.com/stores/01HXXXXXXXXXXXXXXXXXXX/write \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [
        {
          "user": "user:dave",
          "relation": "viewer",
          "object": "document:123"
        }
      ]
    }
  }'
```

Now dave can view the document:

```bash
curl -H "X-User-ID: user:dave" \
  http://localhost:9080/api/documents/123
```

## Caching Behavior

With `cache_ttl: 300`, authorization decisions are cached for 5 minutes.

**First request** (cache miss):
```
[info] ... Checking authorization for user=user:alice resource=document:123 relation=viewer
[info] ... OpenFGA check request: ...
[info] ... OpenFGA check response: allowed=true
```

**Subsequent requests within 5 minutes** (cache hit):
```
[info] ... Cache hit for key: user:alice:document:123:viewer result: true
```

If you revoke access in OpenFGA, it may take up to 5 minutes for the cache to expire. To test immediately, either:

1. Wait for cache to expire
2. Restart APISIX (clears cache)
3. Use a different resource ID
4. Set `cache_ttl: 0` during testing

## Summary

This example demonstrates:
- ✅ Fine-grained access control at the API gateway
- ✅ Different permissions for different users
- ✅ Automatic enforcement without application code changes
- ✅ Centralized authorization via OpenFGA
- ✅ Performance optimization with caching

## Next Steps

- Explore [Multi-Resource Configuration](multi-resource.md)
- Learn about [Custom Relation Mapping](custom-relations.md)
- Read the [Configuration Guide](../docs/configuration.md)
