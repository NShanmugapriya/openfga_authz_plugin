#!/bin/bash

# Setup script for OpenFGA with example store and authorization model
set -e

OPENFGA_URL=${OPENFGA_URL:-"http://localhost:8080"}

echo "Setting up OpenFGA at ${OPENFGA_URL}..."

# Wait for OpenFGA to be ready
echo "Waiting for OpenFGA to be ready..."
timeout 60 bash -c "until curl -f ${OPENFGA_URL}/healthz >/dev/null 2>&1; do sleep 2; done" || {
    echo "Error: OpenFGA is not responding"
    exit 1
}

echo "✓ OpenFGA is ready"

# Create a store
echo "Creating OpenFGA store..."
STORE_RESPONSE=$(curl -s -X POST ${OPENFGA_URL}/stores \
    -H "Content-Type: application/json" \
    -d '{
        "name": "demo-store"
    }')

STORE_ID=$(echo $STORE_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -z "$STORE_ID" ]; then
    echo "Error: Failed to create store"
    echo "Response: $STORE_RESPONSE"
    exit 1
fi

echo "✓ Created store with ID: $STORE_ID"

# Create authorization model
echo "Creating authorization model..."
MODEL_RESPONSE=$(curl -s -X POST ${OPENFGA_URL}/stores/${STORE_ID}/authorization-models \
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
    }')

MODEL_ID=$(echo $MODEL_RESPONSE | grep -o '"authorization_model_id":"[^"]*' | cut -d'"' -f4)

if [ -z "$MODEL_ID" ]; then
    echo "Error: Failed to create authorization model"
    echo "Response: $MODEL_RESPONSE"
    exit 1
fi

echo "✓ Created authorization model with ID: $MODEL_ID"

# Add example tuples
echo "Adding example tuples..."
curl -s -X POST ${OPENFGA_URL}/stores/${STORE_ID}/write \
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
    }' > /dev/null

echo "✓ Added example tuples"

# Output configuration
echo ""
echo "========================================="
echo "OpenFGA Setup Complete!"
echo "========================================="
echo ""
echo "Store ID: ${STORE_ID}"
echo "Authorization Model ID: ${MODEL_ID}"
echo ""
echo "Example Tuples:"
echo "  - user:alice is owner of document:123"
echo "  - user:bob is editor of document:123"
echo "  - user:charlie is viewer of document:123"
echo ""
echo "Use these values in your APISIX configuration:"
echo ""
echo "  openfga_url: ${OPENFGA_URL}"
echo "  store_id: ${STORE_ID}"
echo "  authorization_model_id: ${MODEL_ID}"
echo ""
echo "Test with:"
echo "  curl -H 'X-User-ID: user:alice' http://localhost:9080/api/documents/123"
echo ""
