# Architecture Diagrams

This directory contains architecture diagrams for the OpenFGA Authorization Plugin.

## Request Flow Diagram

```
┌─────────┐
│ Client  │
│         │
└────┬────┘
     │ 1. HTTP Request
     │    GET /api/documents/123
     │    Header: X-User-ID: user:alice
     ▼
┌────────────────────────────────────────┐
│         Apache APISIX Gateway          │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │   OpenFGA AuthZ Plugin           │  │
│  │                                  │  │
│  │  Step 2: Extract Information    │  │
│  │  • User: user:alice             │  │
│  │  • Resource: document:123       │  │
│  │  • Relation: viewer (from GET)  │  │
│  │                                  │  │
│  │  Step 3: Check Cache            │  │
│  │  Key: user:alice:document:      │  │
│  │       123:viewer                │  │
│  └──────────┬───────────────────────┘  │
│             │                          │
│             ▼                          │
│        Cache Hit?                      │
│          /     \                       │
│        Yes     No                      │
│         │       │                      │
│         │       │ 4. Query OpenFGA    │
│         │       ▼                      │
│         │  ┌─────────────────┐        │
│         │  │ POST /check     │        │
│         │  │ {               │        │
│         │  │   user: alice   │────────┼───┐
│         │  │   relation: v.. │        │   │
│         │  │   object: d:123 │        │   │
│         │  └─────────────────┘        │   │
│         │       │                      │   │
│         └───────┤                      │   │
│                 │ 5. Authorization     │   │
│                 │    Decision          │   │
└─────────────────┼──────────────────────┘   │
                  │                          │
                  ▼                          │
            Allowed?                         │
              /   \                          │
          Yes      No                        │
           │        │                        │
           │        │ 6b. Return 403         │
           │        ▼                        │
           │   ┌─────────────┐               │
           │   │   Client    │               │
           │   │  403 Denied │               │
           │   └─────────────┘               │
           │                                 │
           │ 6a. Forward to Upstream         │
           ▼                                 │
┌──────────────────────┐                     │
│  Upstream Service    │                     │
│  (e.g., Document API)│                     │
└──────────┬───────────┘                     │
           │ 7. Response                     │
           ▼                                 │
      ┌─────────┐                            │
      │ Client  │                            │
      │ 200 OK  │                            │
      └─────────┘                            │
                                             │
        ┌────────────────────────────────────┘
        │
        ▼
┌──────────────────┐
│  OpenFGA Server  │
│                  │
│  Store:          │
│  • Tuples        │
│  • Auth Models   │
└──────────────────┘
```

## Caching Flow

```
Request arrives
      │
      ▼
┌──────────────────┐
│ Generate Cache   │
│ Key:             │
│ {user}:          │
│ {resource_type}: │
│ {resource_id}:   │
│ {relation}       │
└─────┬────────────┘
      │
      ▼
┌──────────────────┐
│ Check LRU Cache  │
│ (200 slots)      │
└─────┬────────────┘
      │
      ├─────────────┬─────────────┐
      │             │             │
      ▼             ▼             ▼
  Hit (80%)   Miss (20%)    Expired
      │             │             │
      │             ▼             │
      │      ┌──────────────┐     │
      │      │ Query        │     │
      │      │ OpenFGA      │     │
      │      └──────┬───────┘     │
      │             │             │
      │             ▼             │
      │      ┌──────────────┐     │
      │      │ Store in     │     │
      │      │ Cache        │     │
      │      │ (TTL: 300s)  │     │
      │      └──────┬───────┘     │
      │             │             │
      └─────────────┴─────────────┘
                    │
                    ▼
              Return Result
```

## Component Interaction

```
┌─────────────────────────────────────────────────┐
│              Apache APISIX                      │
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │         Plugin: openfga-authz             │  │
│  │                                           │  │
│  │  ┌─────────────┐    ┌─────────────┐      │  │
│  │  │   Schema    │    │   Access    │      │  │
│  │  │ Validation  │    │   Handler   │      │  │
│  │  └─────────────┘    └──────┬──────┘      │  │
│  │                            │              │  │
│  │  ┌─────────────────────────┴──────────┐   │  │
│  │  │        Helper Functions            │   │  │
│  │  │  • get_resource_id()              │   │  │
│  │  │  • get_relation()                 │   │  │
│  │  │  • check_authorization()          │   │  │
│  │  └────────┬───────────────┬──────────┘   │  │
│  │           │               │              │  │
│  └───────────┼───────────────┼──────────────┘  │
│              │               │                 │
│         Uses │               │ Uses            │
│              ▼               ▼                 │
│     ┌─────────────┐   ┌─────────────┐         │
│     │ LRU Cache   │   │ HTTP Client │         │
│     │ (resty.     │   │ (resty.http)│         │
│     │  lrucache)  │   │             │         │
│     └─────────────┘   └──────┬──────┘         │
│                              │                 │
└──────────────────────────────┼─────────────────┘
                               │ HTTPS
                               ▼
                    ┌──────────────────────┐
                    │    OpenFGA Server    │
                    │                      │
                    │  API Endpoints:      │
                    │  • POST /check       │
                    │  • GET /stores       │
                    │  • ...               │
                    └──────────────────────┘
```

## Authorization Decision Flow

```
┌────────────────────────────────────────────────┐
│         Authorization Check Process            │
└────────────────────────────────────────────────┘

Input:
  • User: user:alice
  • Resource Type: document
  • Resource ID: 123
  • Relation: viewer

        │
        ▼
┌────────────────────────────────────────────────┐
│ 1. Build OpenFGA Tuple                         │
│    {                                           │
│      "user": "user:alice",                     │
│      "relation": "viewer",                     │
│      "object": "document:123"                  │
│    }                                           │
└───────────────────┬────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────────┐
│ 2. Send to OpenFGA                             │
│    POST /stores/{id}/check                     │
└───────────────────┬────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────────┐
│ 3. OpenFGA Evaluates                           │
│    • Check direct relationships                │
│    • Compute inherited permissions             │
│    • Evaluate conditions                       │
└───────────────────┬────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────────┐
│ 4. OpenFGA Returns                             │
│    { "allowed": true/false }                   │
└───────────────────┬────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
┌───────────────┐       ┌───────────────┐
│ If allowed:   │       │ If denied:    │
│ true          │       │ false         │
│               │       │               │
│ • Log success │       │ • Log denial  │
│ • Cache result│       │ • Cache result│
│ • Allow       │       │ • Return 403  │
│   request     │       │               │
└───────────────┘       └───────────────┘
```

## Multi-Tenant Architecture

```
┌──────────────────────────────────────────────┐
│            Multiple Routes                    │
└──────────────────────────────────────────────┘

Route 1: /api/documents/*
┌────────────────────────────────┐
│ openfga-authz                  │
│   resource_type: "document"    │
│   store_id: "store1"           │
└────────────────────────────────┘

Route 2: /api/folders/*
┌────────────────────────────────┐
│ openfga-authz                  │
│   resource_type: "folder"      │
│   store_id: "store1"           │
└────────────────────────────────┘

Route 3: /api/projects/*
┌────────────────────────────────┐
│ openfga-authz                  │
│   resource_type: "project"     │
│   store_id: "store1"           │
└────────────────────────────────┘

        │
        ▼
All routes share:
┌────────────────────────────────┐
│  Same LRU Cache                │
│  (Separate cache keys per      │
│   resource type)                │
└────────────────────────────────┘
        │
        ▼
┌────────────────────────────────┐
│  Single OpenFGA Instance       │
│  • Single Store                │
│  • Multiple Resource Types     │
│  • Unified Authorization Model │
└────────────────────────────────┘
```

## Performance Characteristics

```
Response Time Distribution:

Without Caching:
┌─────────────────────────────────┐
│ APISIX Processing:    1-2ms     │
│ Network to OpenFGA:   5-20ms    │
│ OpenFGA Processing:   10-30ms   │
│ Network back:         5-20ms    │
│ TOTAL:                21-72ms   │
└─────────────────────────────────┘

With Caching (Cache Hit):
┌─────────────────────────────────┐
│ APISIX Processing:    1-2ms     │
│ Cache Lookup:         <1ms      │
│ TOTAL:                1-3ms     │
└─────────────────────────────────┘

Performance Improvement:
┌────────────────────────────────────┐
│                                    │
│  Without Cache: ████████████ 72ms  │
│                                    │
│  With Cache:    █ 3ms              │
│                                    │
│  Speedup: ~24x faster              │
│                                    │
└────────────────────────────────────┘
```

## Notes

These diagrams illustrate the architecture and flow of the OpenFGA Authorization Plugin. For more detailed information, see:

- [Architecture Documentation](../docs/architecture.md)
- [Configuration Guide](../docs/configuration.md)
- [Getting Started](../docs/getting-started.md)
