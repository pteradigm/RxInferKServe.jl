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

# Copy client code including generated proto files
COPY examples/infinite_stream_demo/client/ .

# Set environment for matplotlib
ENV MPLBACKEND=Agg

CMD ["python", "streaming_client.py"]