#!/usr/bin/env python3
"""
Streaming Data Client for RxInferKServe

This client generates synthetic streaming data and sends it to the
RxInferKServe gRPC server for online inference.
"""

import grpc
import numpy as np
import time
import json
from typing import List, Dict, Any, Optional
import matplotlib.pyplot as plt
from collections import deque
import threading
import signal
import sys

# Import the generated gRPC code
# We'll need to generate these from the protobuf file
import sys
import os

# Add proto directory to path
proto_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'proto')
if not os.path.exists(proto_path):
    # If running from /app in Docker
    proto_path = '/app/proto'
sys.path.insert(0, proto_path)

import inference_pb2
import inference_pb2_grpc


class StreamingDataGenerator:
    """Generates synthetic streaming data with various patterns."""
    
    def __init__(self, seed: Optional[int] = None):
        if seed:
            np.random.seed(seed)
        self.t = 0
        self.regime = 0
        self.regime_params = [
            {"mean": 0.0, "std": 1.0, "trend": 0.01},
            {"mean": 2.0, "std": 0.5, "trend": -0.02},
            {"mean": -1.0, "std": 1.5, "trend": 0.0}
        ]
        
    def generate_kalman_data(self, n: int = 1) -> np.ndarray:
        """Generate data for Kalman filter (position with velocity)."""
        data = []
        for _ in range(n):
            # True hidden state: position and velocity
            if not hasattr(self, 'kalman_state'):
                self.kalman_state = np.array([0.0, 0.1])
            
            # State transition with noise
            A = np.array([[1.0, 1.0], [0.0, 1.0]])
            process_noise = np.random.multivariate_normal(
                [0, 0], [[0.01, 0], [0, 0.001]]
            )
            self.kalman_state = A @ self.kalman_state + process_noise
            
            # Observation (position only) with noise
            obs = self.kalman_state[0] + np.random.normal(0, 0.1)
            data.append(obs)
            
        return np.array(data)
    
    def generate_ar_data(self, n: int = 1, change_prob: float = 0.01) -> np.ndarray:
        """Generate AR(1) data with time-varying parameters."""
        data = []
        for _ in range(n):
            if not hasattr(self, 'ar_state'):
                self.ar_state = 0.0
                self.ar_alpha = 0.0
                self.ar_beta = 0.8
            
            # Occasionally change parameters
            if np.random.rand() < change_prob:
                self.ar_alpha += np.random.normal(0, 0.1)
                self.ar_beta += np.random.normal(0, 0.05)
                self.ar_beta = np.clip(self.ar_beta, -0.99, 0.99)
            
            # Generate next value
            self.ar_state = (
                self.ar_alpha + 
                self.ar_beta * self.ar_state + 
                np.random.normal(0, 0.5)
            )
            data.append(self.ar_state)
            
        return np.array(data)
    
    def generate_mixture_data(self, n: int = 1, switch_prob: float = 0.02) -> np.ndarray:
        """Generate data from mixture model with regime switches."""
        data = []
        for _ in range(n):
            # Occasionally switch regime
            if np.random.rand() < switch_prob:
                self.regime = np.random.randint(0, len(self.regime_params))
            
            # Generate from current regime
            params = self.regime_params[self.regime]
            value = np.random.normal(
                params["mean"] + params["trend"] * self.t,
                params["std"]
            )
            data.append(value)
            self.t += 1
            
        return np.array(data)


class RxInferStreamingClient:
    """gRPC client for streaming inference with RxInferKServe."""
    
    def __init__(self, server_address: str = "localhost:8081"):
        self.channel = grpc.insecure_channel(server_address)
        self.stub = inference_pb2_grpc.GRPCInferenceServiceStub(self.channel)
        self.model_states = {}  # Store state for each model
        
    def check_server_live(self) -> bool:
        """Check if server is live."""
        request = inference_pb2.ServerLiveRequest()
        try:
            response = self.stub.ServerLive(request)
            return response.live
        except grpc.RpcError:
            return False
    
    def check_model_ready(self, model_name: str) -> bool:
        """Check if model is ready."""
        request = inference_pb2.ModelReadyRequest(name=model_name)
        try:
            response = self.stub.ModelReady(request)
            return response.ready
        except grpc.RpcError:
            return False
    
    def create_tensor(self, name: str, data: np.ndarray, datatype: str = "FP64") -> Dict:
        """Create tensor in KServe v2 format."""
        # Flatten data to 1D
        flat_data = data.flatten()
        
        # Create InferInputTensor
        tensor = inference_pb2.ModelInferRequest.InferInputTensor(
            name=name,
            datatype=datatype,
            shape=list(data.shape)
        )
        
        # Set contents based on datatype
        if datatype == "FP64":
            tensor.contents.fp64_contents.extend(flat_data.tolist())
        elif datatype == "FP32":
            tensor.contents.fp32_contents.extend(flat_data.astype(np.float32).tolist())
        else:
            raise ValueError(f"Unsupported datatype: {datatype}")
        
        return tensor
    
    def streaming_inference(
        self, 
        model_name: str, 
        data_batch: Dict[str, np.ndarray],
        parameters: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Perform streaming inference on a batch of data."""
        # Create inference request
        request = inference_pb2.ModelInferRequest(
            model_name=model_name,
            id=f"{model_name}_{int(time.time()*1000)}"
        )
        
        # Add input tensors
        for name, data in data_batch.items():
            tensor = self.create_tensor(name, data)
            request.inputs.append(tensor)
        
        # Add parameters if provided
        if parameters:
            for key, value in parameters.items():
                param = inference_pb2.InferParameter()
                if isinstance(value, bool):
                    param.bool_param = value
                elif isinstance(value, int):
                    param.int64_param = value
                elif isinstance(value, str):
                    param.string_param = value
                request.parameters[key].CopyFrom(param)
        
        # Add model state if exists
        if model_name in self.model_states:
            state_param = inference_pb2.InferParameter()
            state_param.string_param = json.dumps(self.model_states[model_name])
            request.parameters["model_state"].CopyFrom(state_param)
        
        # Perform inference
        try:
            response = self.stub.ModelInfer(request)
            
            # Parse outputs
            results = {}
            for output in response.outputs:
                if output.datatype == "FP64":
                    data = np.array(output.contents.fp64_contents)
                elif output.datatype == "FP32":
                    data = np.array(output.contents.fp32_contents)
                else:
                    continue
                    
                # Reshape data
                data = data.reshape(output.shape)
                results[output.name] = data
            
            # Extract and store model state if present
            if "model_state" in response.parameters:
                self.model_states[model_name] = json.loads(
                    response.parameters["model_state"].string_param
                )
            
            return results
            
        except grpc.RpcError as e:
            print(f"gRPC error: {e.code()}: {e.details()}")
            return {}


class StreamingDemo:
    """Main demo class that orchestrates streaming inference."""
    
    def __init__(self, client: RxInferStreamingClient):
        self.client = client
        self.generator = StreamingDataGenerator(seed=42)
        self.running = True
        
        # Data buffers for plotting
        self.kalman_data = deque(maxlen=200)
        self.kalman_estimates = deque(maxlen=200)
        self.ar_data = deque(maxlen=200)
        self.ar_params = deque(maxlen=200)
        self.mixture_data = deque(maxlen=200)
        self.mixture_regimes = deque(maxlen=200)
        
        # Setup signal handler
        signal.signal(signal.SIGINT, self._signal_handler)
        
    def _signal_handler(self, signum, frame):
        """Handle Ctrl+C gracefully."""
        print("\nStopping streaming demo...")
        self.running = False
        
    def run_kalman_stream(self, batch_size: int = 10, interval: float = 0.1):
        """Run Kalman filter streaming demo."""
        print("Starting Kalman filter streaming...")
        
        while self.running:
            # Generate new data
            data = self.generator.generate_kalman_data(batch_size)
            self.kalman_data.extend(data)
            
            # Prepare batch for inference
            batch_data = {"y": data}
            
            # Run inference
            results = self.client.streaming_inference(
                "streaming_kalman",
                batch_data,
                parameters={"Δt": 1.0}
            )
            
            if "x" in results:
                # Extract position estimates
                positions = results["x"][:, 0]
                self.kalman_estimates.extend(positions)
                
                print(f"Processed {batch_size} samples. "
                      f"Latest estimate: {positions[-1]:.3f}, "
                      f"Latest observation: {data[-1]:.3f}")
            
            time.sleep(interval)
    
    def run_ar_stream(self, batch_size: int = 5, interval: float = 0.2):
        """Run AR parameter learning streaming demo."""
        print("Starting AR parameter learning streaming...")
        
        while self.running:
            # Generate new data
            data = self.generator.generate_ar_data(batch_size, change_prob=0.02)
            self.ar_data.extend(data)
            
            # Use sliding window of recent data
            window_size = 20
            if len(self.ar_data) >= window_size:
                window_data = np.array(list(self.ar_data)[-window_size:])
            else:
                window_data = np.array(list(self.ar_data))
            
            # Prepare batch for inference
            batch_data = {"y": window_data}
            
            # Run inference
            results = self.client.streaming_inference(
                "online_ar_learning",
                batch_data,
                parameters={"window_size": window_size}
            )
            
            if "α" in results and "β" in results:
                # Get latest parameter estimates
                alpha = results["α"][-1]
                beta = results["β"][-1]
                self.ar_params.append((alpha, beta))
                
                print(f"Processed {batch_size} samples. "
                      f"Parameters: α={alpha:.3f}, β={beta:.3f}")
            
            time.sleep(interval)
    
    def run_mixture_stream(self, batch_size: int = 20, interval: float = 0.5):
        """Run adaptive mixture model streaming demo."""
        print("Starting adaptive mixture model streaming...")
        
        while self.running:
            # Generate new data
            data = self.generator.generate_mixture_data(batch_size, switch_prob=0.02)
            self.mixture_data.extend(data)
            
            # Prepare batch for inference
            batch_data = {"y": data}
            
            # Run inference
            results = self.client.streaming_inference(
                "adaptive_mixture",
                batch_data,
                parameters={"n_components": 3}
            )
            
            if "z" in results and "π" in results:
                # Get regime assignments and weights
                assignments = results["z"]
                weights = results["π"]
                self.mixture_regimes.extend(assignments)
                
                # Count regime frequencies
                unique, counts = np.unique(assignments, return_counts=True)
                regime_dist = dict(zip(unique, counts))
                
                print(f"Processed {batch_size} samples. "
                      f"Regime distribution: {regime_dist}, "
                      f"Weights: {[f'{w:.2f}' for w in weights]}")
            
            time.sleep(interval)
    
    def plot_results(self):
        """Create live plots of streaming results."""
        # Check if we can display
        import os
        if not os.environ.get('DISPLAY') and not os.environ.get('MPLBACKEND'):
            print("No display available, skipping visualization")
            return
            
        plt.ion()
        fig, axes = plt.subplots(3, 1, figsize=(10, 8))
        
        while self.running:
            # Clear axes
            for ax in axes:
                ax.clear()
            
            # Plot Kalman filter results
            if self.kalman_data:
                axes[0].plot(list(self.kalman_data), 'b.', alpha=0.5, label='Observations')
                if self.kalman_estimates:
                    axes[0].plot(list(self.kalman_estimates), 'r-', label='Estimates')
                axes[0].set_title('Kalman Filter: Position Tracking')
                axes[0].legend()
                axes[0].grid(True)
            
            # Plot AR data and parameters
            if self.ar_data:
                axes[1].plot(list(self.ar_data), 'g-', label='AR Process')
                axes[1].set_title('AR(1) Process with Time-Varying Parameters')
                axes[1].legend()
                axes[1].grid(True)
            
            # Plot mixture data with regime coloring
            if self.mixture_data and self.mixture_regimes:
                data = np.array(list(self.mixture_data))
                regimes = np.array(list(self.mixture_regimes))
                
                # Color by regime
                colors = ['red', 'blue', 'green']
                for i in range(3):
                    mask = regimes == i
                    if np.any(mask):
                        axes[2].scatter(
                            np.where(mask)[0], 
                            data[mask], 
                            c=colors[i], 
                            alpha=0.6, 
                            label=f'Regime {i}'
                        )
                
                axes[2].set_title('Mixture Model: Regime Detection')
                axes[2].legend()
                axes[2].grid(True)
            
            plt.tight_layout()
            plt.pause(1.0)
        
        plt.ioff()


def main():
    """Main function to run the streaming demo."""
    print("="*60)
    print("RxInferKServe Infinite Data Stream Demo")
    print("="*60)
    
    # Create client
    server_address = os.environ.get("RXINFER_SERVER", "localhost:8081")
    if server_address == "localhost:8081":
        # Check if running in container (works for both Docker and Podman)
        if os.path.exists("/.dockerenv") or os.path.exists("/run/.containerenv"):
            server_address = "rxinfer-server:8081"
    
    print(f"\n1. Connecting to server at {server_address}...")
    client = RxInferStreamingClient(server_address)
    
    # Wait for server to be ready
    max_retries = 30
    for i in range(max_retries):
        if client.check_server_live():
            print("   ✓ Server is live!")
            break
        print(f"   Waiting for server... ({i+1}/{max_retries})")
        time.sleep(1)
    else:
        print("   ✗ ERROR: Server failed to respond!")
        sys.exit(1)
    
    # Check models are ready
    print("\n2. Checking model availability...")
    models = ["streaming_kalman", "online_ar_learning", "adaptive_mixture"]
    all_ready = True
    for model in models:
        for i in range(10):
            if client.check_model_ready(model):
                print(f"   ✓ Model {model} is ready!")
                break
            time.sleep(0.5)
        else:
            print(f"   ✗ Model {model} failed to become ready!")
            all_ready = False
    
    if not all_ready:
        print("\n✗ ERROR: Not all models are ready!")
        sys.exit(1)
    
    print("\n3. Starting streaming inference...")
    print("   - Kalman Filter: Tracking position with velocity")
    print("   - AR Learning: Estimating time-varying parameters") 
    print("   - Mixture Model: Detecting regime changes")
    print("\n" + "="*60)
    print("STREAMING DATA - Press Ctrl+C to stop")
    print("="*60 + "\n")
    
    # Create demo
    demo = StreamingDemo(client)
    
    # Start streaming threads
    import threading
    threads = [
        threading.Thread(target=demo.run_kalman_stream),
        threading.Thread(target=demo.run_ar_stream),
        threading.Thread(target=demo.run_mixture_stream),
        threading.Thread(target=demo.plot_results)
    ]
    
    # Start all threads
    for thread in threads:
        thread.daemon = True
        thread.start()
    
    # Wait for interrupt and show statistics
    start_time = time.time()
    last_stats_time = start_time
    
    try:
        while demo.running:
            time.sleep(1)
            
            # Print statistics every 10 seconds
            if time.time() - last_stats_time > 10:
                elapsed = time.time() - start_time
                print(f"\n--- Statistics after {elapsed:.0f}s ---")
                print(f"Kalman samples: {len(demo.kalman_data)}")
                print(f"AR samples: {len(demo.ar_data)}")
                print(f"Mixture samples: {len(demo.mixture_data)}")
                
                if demo.kalman_data and demo.kalman_estimates:
                    # Calculate RMSE for Kalman filter
                    data = np.array(list(demo.kalman_data))[-100:]
                    estimates = np.array(list(demo.kalman_estimates))[-100:]
                    min_len = min(len(data), len(estimates))
                    if min_len > 0:
                        rmse = np.sqrt(np.mean((data[:min_len] - estimates[:min_len])**2))
                        print(f"Kalman RMSE: {rmse:.3f}")
                
                print("---\n")
                last_stats_time = time.time()
                
    except KeyboardInterrupt:
        print("\n\nShutting down gracefully...")
    
    # Final statistics
    elapsed = time.time() - start_time
    print(f"\n{'='*60}")
    print("DEMO COMPLETED SUCCESSFULLY")
    print(f"{'='*60}")
    print(f"Total runtime: {elapsed:.1f} seconds")
    print(f"Total samples processed:")
    print(f"  - Kalman filter: {len(demo.kalman_data)}")
    print(f"  - AR model: {len(demo.ar_data)}")
    print(f"  - Mixture model: {len(demo.mixture_data)}")
    
    if elapsed > 0:
        print(f"\nThroughput:")
        print(f"  - Kalman: {len(demo.kalman_data)/elapsed:.1f} samples/sec")
        print(f"  - AR: {len(demo.ar_data)/elapsed:.1f} samples/sec")
        print(f"  - Mixture: {len(demo.mixture_data)/elapsed:.1f} samples/sec")
    
    print(f"\n✓ All systems performed successfully!")
    print("="*60)


if __name__ == "__main__":
    main()