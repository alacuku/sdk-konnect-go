#!/bin/bash -e

readonly GENERATED_FILE=zz_generated.openapi.go
readonly OUTPUT_DIR=models/components
readonly OUTPUT_PKG=github.com/Kong/sdk-konnect-go/models/components
readonly OPENAPI_GEN_MARKER="+k8s:openapi-gen=true"

# Install openapi-gen if not already available
if ! command -v openapi-gen &> /dev/null; then
    echo "Installing openapi-gen..."
    go install k8s.io/kube-openapi/cmd/openapi-gen@latest
fi

# Define the exact list of types to generate OpenAPI schemas for
# These are the types with DeepCopy and the enum/primitive types they reference
TARGET_TYPES=(
    # Types with DeepCopy
    "CreateControlPlaneRequest"
    "CreateNetworkRequest"
    "Destinations"
    "Healthchecks"
    "Sources"
    "UpstreamClientCertificate"
    
    # Referenced enum/string types
    "APIAccess"
    "AuthType"
    "ControlPlaneClusterType"
    "CreateControlPlaneRequestClusterType"
    "CreateService"
    "CreateTransitGatewayRequest"
    "HTTPSRedirectStatusCode"
    "HashFallback"
    "HashOn"
    "InstanceTypeName"
    "NetworkCreateState"
    "PathHandling"
    "Protocol"
    "ProviderName"
    "RouteJSONProtocols"
    "ServiceInput"
    "TransitGatewayState"
    "UpstreamAlgorithm"
    
    # Additional referenced struct types
    "ProxyURL"
    "Healthy"
    "Unhealthy"
    "Active"
    "Passive"
    "UpstreamHealthy"
    "UpstreamUnhealthy"
)

echo "Generating OpenAPI schemas for the following types:"
printf '  - %s\n' "${TARGET_TYPES[@]}"
echo ""

# Function to add marker to a type
add_marker_to_type() {
    local type_name=$1
    local files=$(grep -l "^type ${type_name} " ${OUTPUT_DIR}/*.go 2>/dev/null | grep -v zz_generated)
    
    for file in $files; do
        # Check if marker already exists
        if ! grep -B1 "^type ${type_name} " "$file" | grep -q "${OPENAPI_GEN_MARKER}"; then
            echo "  Adding marker to ${type_name} in $(basename $file)"
            # Add marker before type declaration
            sed -i "s|^\(type ${type_name} \)|// ${OPENAPI_GEN_MARKER}\n\1|g" "$file"
        fi
    done
}

# Add markers to all target types
echo "Adding OpenAPI generation markers..."
for type in "${TARGET_TYPES[@]}"; do
    add_marker_to_type "$type"
done

echo ""
echo "Generating OpenAPI definitions..."

# Generate OpenAPI definitions
openapi-gen \
    -v 2 \
    --output-file ${GENERATED_FILE} \
    --output-dir ${OUTPUT_DIR} \
    --output-pkg ${OUTPUT_PKG} \
    --go-header-file hack/header-template.go.tmpl \
    --report-filename /dev/null \
    ./${OUTPUT_DIR}

# Tidy up dependencies
go mod tidy

echo ""
echo "Cleaning up markers..."

# Remove the markers from source files
for type in "${TARGET_TYPES[@]}"; do
    files=$(grep -l "^type ${type} " ${OUTPUT_DIR}/*.go 2>/dev/null | grep -v zz_generated)
    for file in $files; do
        sed -i "/\/\/ ${OPENAPI_GEN_MARKER}/d" "$file"
    done
done

echo ""
echo "✓ OpenAPI generation completed: ${OUTPUT_DIR}/${GENERATED_FILE}"


