# Architecture Overview

This document provides an architectural overview of the OpenFGA Authorization Plugin for Apache APISIX.

## Table of Contents

- [System Architecture](#system-architecture)
- [Component Overview](#component-overview)
- [Request Flow](#request-flow)
- [Plugin Lifecycle](#plugin-lifecycle)
- [Data Flow](#data-flow)
- [Caching Strategy](#caching-strategy)
- [Error Handling](#error-handling)
- [Performance Considerations](#performance-considerations)

## System Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ HTTP Request
       │ (with X-User-ID header)
       ▼
┌──────────────────────────────────────┐
│         Apache APISIX                │
│  ┌────────────────────────────────┐  │
│  │   OpenFGA AuthZ Plugin         │  │
│  │  ┌──────────────────────────┐  │  │
│  │  │  1. Extract User         │  │  │
│  │  │  2. Extract Resource ID  │  │  │
│  │  │  3. Determine Relation   │  │  │
│  │  │  4. Check Cache          │  │  │
│  │  │  5. Query OpenFGA        │  │  │
│  │  │  6. Update Cache         │  │  │
│  │  │  7. Allow/Deny Request   │  │  │
│  │  └──────────────────────────┘  │  │
│  └────────────────────────────────┘  │
└───────┬──────────────┬───────────────┘
        │              │
        │              │ OpenFGA Check
        │              ▼
        │         ┌──────────────┐
        │         │   OpenFGA    │
        │         │   Server     │
        │         └──────────────┘
        │ (if authorized)
        ▼
┌──────────────┐
│  Upstream    │
│  Service     │
└──────────────┘
```

## Component Overview

### 1. Plugin Core (`openfga-authz.lua`)

The main plugin file contains:

- **Schema Definition**: Validates plugin configuration
- **Access Phase Handler**: Intercepts requests for authorization
- **Helper Functions**:
  - `get_resource_id()`: Extracts resource ID from request
  - `get_relation()`: Maps HTTP method to OpenFGA relation
  - `check_authorization()`: Queries OpenFGA for authorization decision

### 2. Configuration Schema

```lua
{
  openfga_url: string (required),
  store_id: string (required),
  authorization_model_id: string (optional),
  user_header: string (default: "X-User-ID"),
  resource_type: string (required),
  relation_mapping: object (optional),
  id_location: enum (default: "last_path_segment"),
  id_param_name: string (optional),
  cache_ttl: integer (default: 300),
  timeout: integer (default: 3000),
  ssl_verify: boolean (default: true)
}
```

### 3. LRU Cache

- **Implementation**: `resty.lrucache`
- **Size**: 200 slots (hardcoded)
- **Key Format**: `{user}:{resource_type}:{resource_id}:{relation}`
- **TTL**: Configurable per route (default: 300 seconds)

### 4. HTTP Client

- **Implementation**: `resty.http`
- **Features**:
  - Connection pooling
  - Configurable timeout
  - SSL/TLS support

## Request Flow

### Detailed Flow Diagram

```
Client Request
      │
      ▼
┌─────────────────────┐
│  APISIX Receives    │
│  Request            │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Plugin: Access     │
│  Phase Triggered    │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────────────┐
│  Extract User from Header   │
│  (e.g., X-User-ID)          │
└─────────┬───────────────────┘
          │
          ├─────────────────────┐
          │                     │
          ▼                     ▼
    User Found?            User Not Found
          │                     │
          │                     ▼
          │              Return 401
          │              "User header
          │               not found"
          │
          ▼
┌─────────────────────────────┐
│  Extract Resource ID        │
│  (from URI/query/header)    │
└─────────┬───────────────────┘
          │
          ├─────────────────────┐
          │                     │
          ▼                     ▼
    ID Found?               ID Not Found
          │                     │
          │                     ▼
          │              Return 400
          │              "Resource ID
          │               not found"
          │
          ▼
┌─────────────────────────────┐
│  Determine Relation         │
│  (based on HTTP method)     │
└─────────┬───────────────────┘
          │
          ▼
┌─────────────────────────────┐
│  Check Cache                │
│  Key: user:type:id:relation │
└─────────┬───────────────────┘
          │
          ├───────────────┐
          │               │
          ▼               ▼
    Cache Hit?      Cache Miss
          │               │
          │               ▼
          │      ┌─────────────────┐
          │      │  Call OpenFGA   │
          │      │  Check API      │
          │      └────────┬────────┘
          │               │
          │               ▼
          │      ┌─────────────────┐
          │      │  Update Cache   │
          │      └────────┬────────┘
          │               │
          └───────────────┘
                  │
                  ▼
         ┌────────────────┐
         │  Authorized?   │
         └────────┬───────┘
                  │
          ┌───────┴───────┐
          ▼               ▼
       Yes              No
          │               │
          ▼               ▼
   Allow Request    Return 403
   to Upstream      "Access denied"
```

## Plugin Lifecycle

### 1. Configuration Phase

```lua
function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end
```

- Validates plugin configuration
- Occurs during route creation/update
- Ensures required fields are present

### 2. Access Phase

```lua
function _M.access(conf, ctx)
    -- Extract user
    -- Extract resource ID
    -- Determine relation
    -- Check authorization
    -- Allow or deny
end
```

- Runs for every request
- Executes before request reaches upstream
- Can short-circuit with 401, 403, or 500

### 3. Plugin Priority

- **Priority**: 2555
- Runs after authentication plugins (higher priority)
- Runs before most transformation plugins (lower priority)

## Data Flow

### Authorization Check Request

```
APISIX Plugin → OpenFGA
POST /stores/{store_id}/check

Request Body:
{
  "tuple_key": {
    "user": "user:alice",
    "relation": "viewer",
    "object": "document:123"
  },
  "authorization_model_id": "..." (optional)
}

Response:
{
  "allowed": true
}
```

### Cache Entry

```
Key: "user:alice:document:123:viewer"
Value: true
TTL: 300 seconds
```

## Caching Strategy

### Cache Key Design

Format: `{user}:{resource_type}:{resource_id}:{relation}`

**Example Keys**:
- `user:alice:document:123:viewer`
- `user:bob:folder:456:editor`
- `team:developers:project:789:owner`

### Cache Behavior

1. **On Cache Hit**:
   - Return cached decision immediately
   - No OpenFGA call
   - Log cache hit

2. **On Cache Miss**:
   - Query OpenFGA
   - Store result in cache with TTL
   - Return decision

3. **On Cache Expiry**:
   - Entry removed from cache
   - Next request causes cache miss
   - Fresh check with OpenFGA

### Cache Invalidation

- **Time-based**: TTL expiration (configurable)
- **No explicit invalidation**: Changes in OpenFGA won't be reflected until cache expires
- **Workaround**: Set `cache_ttl: 0` for no caching

### LRU Eviction

- Cache size: 200 entries
- When full, least recently used entry is evicted
- Consider increasing size for high-traffic deployments

## Error Handling

### Error Scenarios

| Scenario | HTTP Status | Response |
|----------|-------------|----------|
| User header missing | 401 | `{"message": "Unauthorized: User header not found"}` |
| Resource ID not found | 400 | `{"message": "Bad Request: Resource ID not found"}` |
| OpenFGA connection failed | 500 | `{"message": "Internal Server Error: OpenFGA request failed"}` |
| OpenFGA non-200 response | 500 | `{"message": "Internal Server Error: OpenFGA check failed"}` |
| Invalid OpenFGA response | 500 | `{"message": "Internal Server Error: Invalid OpenFGA response"}` |
| Access denied | 403 | `{"message": "Forbidden: Access denied"}` |

### Logging

All errors are logged with appropriate levels:

- **Error**: Connection failures, invalid responses
- **Warn**: Access denied (expected scenario)
- **Info**: Successful checks, cache hits

## Performance Considerations

### Latency Impact

**Without Caching**:
- Base latency: 5-50ms (network + OpenFGA processing)
- Additional latency per request

**With Caching** (cache hit):
- Base latency: < 1ms
- Negligible impact

### Throughput

**Bottlenecks**:
1. OpenFGA query latency (for cache misses)
2. Network latency between APISIX and OpenFGA
3. OpenFGA server capacity

**Optimizations**:
1. Enable caching with appropriate TTL
2. Deploy OpenFGA close to APISIX (same VPC/network)
3. Scale OpenFGA horizontally if needed
4. Use connection pooling (automatic with resty.http)

### Resource Usage

**Memory**:
- Cache: ~200 entries × ~100 bytes = ~20KB
- Negligible memory footprint

**CPU**:
- Minimal CPU usage
- Most time spent in I/O (network)

### Scaling Recommendations

1. **Low Traffic** (< 100 req/s):
   - Default configuration works well
   - Cache TTL: 300s

2. **Medium Traffic** (100-1000 req/s):
   - Increase cache TTL: 600s
   - Ensure OpenFGA is on same network

3. **High Traffic** (> 1000 req/s):
   - Consider higher cache TTL: 1800s+
   - Scale OpenFGA horizontally
   - Monitor cache hit rate
   - Consider increasing cache size in plugin code

## Security Considerations

### SSL/TLS

- Always use `ssl_verify: true` in production
- Use HTTPS for OpenFGA URL
- Secure communication channel

### Secrets Management

- Store OpenFGA credentials securely
- Use environment variables or secret management systems
- Don't commit credentials to source control

### Authorization Model

- Design authorization model carefully
- Test thoroughly before production
- Monitor for unauthorized access attempts

### Logging

- Be careful not to log sensitive user data
- Current implementation logs user IDs and resource IDs
- Consider GDPR/privacy regulations

## Monitoring and Observability

### Metrics to Track

1. **Authorization Check Latency**
   - p50, p95, p99 latency
   - Track both cache hits and misses

2. **Cache Hit Rate**
   - Percentage of requests served from cache
   - Should be > 80% for optimal performance

3. **Authorization Denial Rate**
   - Percentage of requests denied
   - Spike might indicate attack or misconfiguration

4. **Error Rate**
   - OpenFGA connection failures
   - Invalid responses

### Log Analysis

Example log patterns:

```
# Successful authorization
[info] Access granted for user=user:alice resource=document:123 relation=viewer

# Cache hit
[info] Cache hit for key: user:alice:document:123:viewer result: true

# Access denied
[warn] Access denied for user=user:charlie resource=document:456 relation=editor

# Error
[error] Failed to check authorization: connection refused
```

## Future Enhancements

1. **Batch Authorization Checks**
   - Check multiple resources in single request
   - Reduce latency for list operations

2. **Prometheus Metrics**
   - Expose plugin metrics
   - Monitor cache hit rate, latency, errors

3. **Dynamic Cache Size**
   - Make cache size configurable
   - Auto-scale based on traffic

4. **Streaming API Support**
   - Use OpenFGA streaming API
   - Watch for permission changes
   - Proactive cache invalidation

5. **Admin API Integration**
   - Manage plugin configuration via Admin API
   - Dynamic reload without restart

## References

- [Apache APISIX Plugin Development](https://apisix.apache.org/docs/apisix/plugin-develop/)
- [OpenFGA Documentation](https://openfga.dev/docs/)
- [Google Zanzibar Paper](https://research.google/pubs/pub48190/)
- [Lua-resty-http](https://github.com/ledgetech/lua-resty-http)
- [Lua-resty-lrucache](https://github.com/openresty/lua-resty-lrucache)
