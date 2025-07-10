#!/bin/bash
# Generate Python gRPC code from protobuf definition

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../../.." && pwd )"
PROTO_DIR="$PROJECT_ROOT/proto"
OUT_DIR="$SCRIPT_DIR/../proto"

# Create output directory
mkdir -p "$OUT_DIR"

# Generate Python code
echo "Generating Python gRPC code from protobuf..."
python -m grpc_tools.protoc \
    -I"$PROTO_DIR" \
    --python_out="$OUT_DIR" \
    --grpc_python_out="$OUT_DIR" \
    "$PROTO_DIR/kserve/v2/inference.proto"

# Fix imports in generated files (grpc_tools generates absolute imports)
echo "Fixing imports in generated files..."
sed -i 's/import kserve.v2.inference_pb2/import inference_pb2/' "$OUT_DIR/kserve/v2/inference_pb2_grpc.py" 2>/dev/null || \
sed -i '' 's/import kserve.v2.inference_pb2/import inference_pb2/' "$OUT_DIR/kserve/v2/inference_pb2_grpc.py"

# Move files to proto directory
mv "$OUT_DIR/kserve/v2/"*.py "$OUT_DIR/"
rm -rf "$OUT_DIR/kserve"

echo "Proto generation complete!"