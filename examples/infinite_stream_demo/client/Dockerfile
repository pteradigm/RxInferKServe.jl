FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY examples/infinite_stream_demo/client/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy proto files
COPY proto /proto

# Generate Python proto files
RUN mkdir -p proto && \
    python -m grpc_tools.protoc \
    -I/proto \
    --python_out=proto \
    --grpc_python_out=proto \
    /proto/kserve/v2/inference.proto && \
    mv proto/kserve/v2/*.py proto/ && \
    rm -rf proto/kserve && \
    sed -i 's/from kserve.v2 import inference_pb2/import inference_pb2/' proto/inference_pb2_grpc.py || true

# Copy client code
COPY examples/infinite_stream_demo/client/ .

# Set environment for matplotlib
ENV MPLBACKEND=Agg

CMD ["python", "streaming_client.py"]