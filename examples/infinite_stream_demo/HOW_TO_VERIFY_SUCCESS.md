# How to Verify the Infinite Stream Demo is Working

## Quick Check (< 30 seconds)

From the project root:
```bash
make demo-stream-status
```

You should see:
```
✓ rxinfer-streaming-server is running
✓ rxinfer-streaming-client is running
✓ Server health check passed
✓ Model streaming_kalman is registered
✓ Model online_ar_learning is registered
✓ Model adaptive_mixture is registered
✓ Client connected to server
✓ Models are ready
✓ Data is being processed
✓ No errors in recent logs

======================================
✓ DEMO IS RUNNING SUCCESSFULLY
======================================
```

## Manual Verification (1-2 minutes)

### 1. Start the Demo
```bash
cd docker
podman-compose up --build
```

Note: The `docker/` directory name is kept as a standard convention, but we use podman-compose with it.

### 2. Watch for Startup Messages

Within 30 seconds, you should see:

**Server Side:**
```
rxinfer-server | Starting RxInferKServe with streaming models...
rxinfer-server | Streaming models registered successfully!
rxinfer-server | Server listening on:
rxinfer-server |   HTTP: http://0.0.0.0:8080 (mapped to host port 8090)
rxinfer-server |   gRPC: 0.0.0.0:8081 (mapped to host port 8091)
```

**Client Side:**
```
streaming-client | ============================================================
streaming-client | RxInferKServe Infinite Data Stream Demo
streaming-client | ============================================================
streaming-client | 
streaming-client | 1. Connecting to server at rxinfer-server:8081...
streaming-client |    ✓ Server is live!
streaming-client | 
streaming-client | 2. Checking model availability...
streaming-client |    ✓ Model streaming_kalman is ready!
streaming-client |    ✓ Model online_ar_learning is ready!
streaming-client |    ✓ Model adaptive_mixture is ready!
```

### 3. Confirm Continuous Processing

After startup, you should see continuous output like:
```
streaming-client | Processed 10 samples. Latest estimate: 2.341, Latest observation: 2.367
streaming-client | Processed 5 samples. Parameters: α=0.023, β=0.812
streaming-client | Processed 20 samples. Regime distribution: {0: 7, 1: 11, 2: 2}, Weights: ['0.35', '0.55', '0.10']
```

This output should continue indefinitely with:
- New lines appearing every 0.1-0.5 seconds
- Different values each time
- No error messages

### 4. Check Statistics (after 10 seconds)

Every 10 seconds, you'll see a statistics summary:
```
streaming-client | --- Statistics after 10s ---
streaming-client | Kalman samples: 100
streaming-client | AR samples: 50  
streaming-client | Mixture samples: 20
streaming-client | Kalman RMSE: 0.124
streaming-client | ---
```

### 5. Graceful Shutdown

Press Ctrl+C and you should see:
```
streaming-client | Shutting down gracefully...
streaming-client | 
streaming-client | ============================================================
streaming-client | DEMO COMPLETED SUCCESSFULLY
streaming-client | ============================================================
streaming-client | Total runtime: 45.2 seconds
streaming-client | Total samples processed:
streaming-client |   - Kalman filter: 452
streaming-client |   - AR model: 226
streaming-client |   - Mixture model: 90
streaming-client | 
streaming-client | Throughput:
streaming-client |   - Kalman: 10.0 samples/sec
streaming-client |   - AR: 5.0 samples/sec
streaming-client |   - Mixture: 2.0 samples/sec
streaming-client | 
streaming-client | ✓ All systems performed successfully!
streaming-client | ============================================================
```

## Success Criteria Summary

✅ **The demo is successful if:**
1. Both containers start without errors
2. All 3 models register and become ready
3. Continuous data processing occurs (new output every second)
4. Statistics show increasing sample counts
5. No error messages appear in logs
6. Graceful shutdown on Ctrl+C

❌ **The demo has failed if:**
1. Containers exit immediately
2. "ERROR" or "Exception" messages appear
3. No processing output after 30 seconds
4. Statistics show 0 samples after running
5. Server health check fails

## Common Issues & Solutions

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| "Address already in use" | Port conflict | `lsof -i :8090,8091` and kill processes |
| "Model not ready" loop | Server startup issue | Check server logs: `podman logs rxinfer-server` |
| No processing output | gRPC connection failed | Restart: `podman-compose down && podman-compose up` |
| Very slow startup | First-time Julia compilation | Wait 2-3 minutes on first run |

## Test the gRPC Connection Directly

```bash
# Test server is responding
curl http://localhost:8090/v2/health/live

# List available models
curl http://localhost:8090/v2/models | jq

# Expected output:
{
  "models": [
    {"name": "streaming_kalman", "state": "READY"},
    {"name": "online_ar_learning", "state": "READY"},
    {"name": "adaptive_mixture", "state": "READY"}
  ]
}
```

## View Detailed Logs

```bash
# Server logs only
podman-compose logs -f rxinfer-server

# Client logs only  
podman-compose logs -f streaming-client

# Both with timestamps
podman-compose logs -f --timestamps
```

## Performance Expectations

When running successfully, you should see:
- **Kalman Filter**: ~10 updates/second (100ms intervals)
- **AR Model**: ~5 updates/second (200ms intervals)
- **Mixture Model**: ~2 updates/second (500ms intervals)
- **Total throughput**: ~170 samples/second across all models
- **Memory usage**: Stable (no continuous growth)
- **CPU usage**: Moderate (20-40% on modern hardware)