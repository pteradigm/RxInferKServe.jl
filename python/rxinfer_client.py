"""
Python client for RxInferKServe (KServe v2 compatible)
"""

import json
from typing import Dict, Any, Optional, List, Union
from uuid import UUID, uuid4

import requests
from pydantic import BaseModel, Field


class TensorMetadata(BaseModel):
    name: str
    datatype: str
    shape: List[int]


class ModelMetadata(BaseModel):
    name: str
    versions: List[str]
    platform: str
    inputs: List[TensorMetadata]
    outputs: List[TensorMetadata]


class InferenceRequest(BaseModel):
    id: Optional[str] = None
    inputs: List[Dict[str, Any]]
    outputs: Optional[List[Dict[str, Any]]] = None
    parameters: Optional[Dict[str, Any]] = None


class InferenceResponse(BaseModel):
    model_name: str
    model_version: Optional[str] = None
    id: str
    outputs: List[Dict[str, Any]]
    parameters: Optional[Dict[str, Any]] = None


class RxInferClient:
    """Python client for RxInferKServe (KServe v2 compatible)"""
    
    def __init__(self, base_url: str = "http://localhost:8080", 
                 api_key: Optional[str] = None,
                 timeout: int = 30):
        self.base_url = base_url.rstrip('/')
        self.api_key = api_key
        self.timeout = timeout
        self.session = requests.Session()
        
        # Set headers
        self.session.headers.update({
            "Content-Type": "application/json",
            "Accept": "application/json"
        })
        
        if api_key:
            self.session.headers["X-API-Key"] = api_key
    
    def server_live(self) -> bool:
        """Check if server is live (KServe v2)"""
        response = self.session.get(
            f"{self.base_url}/v2/health/live",
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json().get("live", False)
    
    def server_ready(self) -> bool:
        """Check if server is ready (KServe v2)"""
        response = self.session.get(
            f"{self.base_url}/v2/health/ready",
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json().get("ready", False)
    
    def model_ready(self, model_name: str, model_version: Optional[str] = None) -> bool:
        """Check if model is ready (KServe v2)"""
        url = f"{self.base_url}/v2/models/{model_name}/ready"
        if model_version:
            url = f"{self.base_url}/v2/models/{model_name}/versions/{model_version}/ready"
            
        response = self.session.get(url, timeout=self.timeout)
        response.raise_for_status()
        return response.json().get("ready", False)
    
    def list_models(self) -> List[str]:
        """List available models (KServe v2)"""
        response = self.session.get(
            f"{self.base_url}/v2/models",
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()
    
    def model_metadata(self, model_name: str, model_version: Optional[str] = None) -> ModelMetadata:
        """Get model metadata (KServe v2)"""
        url = f"{self.base_url}/v2/models/{model_name}"
        if model_version:
            url = f"{self.base_url}/v2/models/{model_name}/versions/{model_version}"
            
        response = self.session.get(url, timeout=self.timeout)
        response.raise_for_status()
        data = response.json()
        
        # Convert tensor metadata
        inputs = [TensorMetadata(**inp) for inp in data.get("inputs", [])]
        outputs = [TensorMetadata(**out) for out in data.get("outputs", [])]
        
        return ModelMetadata(
            name=data["name"],
            versions=data.get("versions", []),
            platform=data.get("platform", "RxInfer.jl"),
            inputs=inputs,
            outputs=outputs
        )
    
    def infer(self, model_name: str, 
              inputs: List[Dict[str, Any]],
              model_version: Optional[str] = None,
              outputs: Optional[List[Dict[str, Any]]] = None,
              parameters: Optional[Dict[str, Any]] = None,
              request_id: Optional[str] = None) -> InferenceResponse:
        """Run inference on a model (KServe v2)"""
        url = f"{self.base_url}/v2/models/{model_name}/infer"
        if model_version:
            url = f"{self.base_url}/v2/models/{model_name}/versions/{model_version}/infer"
        
        request_data = InferenceRequest(
            id=request_id or str(uuid4()),
            inputs=inputs,
            outputs=outputs,
            parameters=parameters
        )
        
        response = self.session.post(
            url,
            json=request_data.model_dump(exclude_none=True),
            timeout=self.timeout
        )
        response.raise_for_status()
        return InferenceResponse(**response.json())
    
    def infer_simple(self, model_name: str, 
                    data: Dict[str, Any],
                    model_version: Optional[str] = None,
                    parameters: Optional[Dict[str, Any]] = None,
                    request_id: Optional[str] = None) -> InferenceResponse:
        """Simplified inference for single data dict (convenience method)"""
        # Convert simple data dict to KServe tensor format
        inputs = []
        for name, value in data.items():
            if isinstance(value, list):
                inputs.append({
                    "name": name,
                    "datatype": "FP64",  # Default to float64
                    "shape": [len(value)],
                    "data": value
                })
            elif isinstance(value, (int, float)):
                inputs.append({
                    "name": name,
                    "datatype": "FP64",
                    "shape": [1],
                    "data": [value]
                })
            else:
                # Convert to JSON string for complex types
                inputs.append({
                    "name": name,
                    "datatype": "BYTES",
                    "shape": [1],
                    "data": [json.dumps(value)]
                })
        
        return self.infer(
            model_name=model_name,
            inputs=inputs,
            model_version=model_version,
            parameters=parameters,
            request_id=request_id
        )
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.session.close()


# Convenience functions for working with distributions
def parse_distribution(dist_dict: Dict[str, Any]) -> Dict[str, Any]:
    """Parse a serialized distribution"""
    if not isinstance(dist_dict, dict) or "type" not in dist_dict:
        return dist_dict
    
    dist_type = dist_dict["type"]
    params = dist_dict.get("parameters", {})
    
    # Add parsing logic for specific distribution types
    if "Normal" in dist_type:
        return {
            "type": "normal",
            "mean": params.get("mean", 0.0),
            "std": params.get("std", 1.0)
        }
    elif "Beta" in dist_type:
        return {
            "type": "beta",
            "alpha": params.get("alpha", 1.0),
            "beta": params.get("beta", 1.0)
        }
    # Add more distribution types as needed
    
    return dist_dict


# Example usage
if __name__ == "__main__":
    # Create client
    client = RxInferClient()
    
    # Check server status
    live = client.server_live()
    ready = client.server_ready()
    print(f"Server live: {live}, ready: {ready}")
    
    # List models
    models = client.list_models()
    print(f"Available models: {models}")
    
    # Get model metadata
    if models:
        model_name = models[0]
        metadata = client.model_metadata(model_name)
        print(f"Model {model_name} metadata: {metadata}")
        
        # Check if model is ready
        model_ready = client.model_ready(model_name)
        print(f"Model {model_name} ready: {model_ready}")
        
        # Run inference using simple method
        data = {
            "y": [1, 0, 1, 1, 0, 1, 1, 1, 0, 1]
        }
        
        result = client.infer_simple(model_name, data)
        print(f"Inference result: {result}")
        
        # Or run inference using full KServe v2 format
        inputs = [{
            "name": "y",
            "datatype": "FP64",
            "shape": [10],
            "data": [1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 0.0, 1.0]
        }]
        
        result = client.infer(model_name, inputs)
        print(f"Inference result (full format): {result}")