"""
Python client for RxInferMLServer
"""

import json
from typing import Dict, Any, Optional, List, Union
from uuid import UUID, uuid4

import requests
from pydantic import BaseModel, Field


class ModelMetadata(BaseModel):
    name: str
    version: str
    description: str
    created_at: str
    parameters: Dict[str, Any] = Field(default_factory=dict)


class ModelInstance(BaseModel):
    id: str
    model_name: str
    created_at: str
    metadata: ModelMetadata


class InferenceResponse(BaseModel):
    request_id: str
    model_id: str
    results: Dict[str, Any]
    metadata: Dict[str, Any]
    timestamp: str
    duration_ms: float


class RxInferClient:
    """Python client for RxInferMLServer"""
    
    def __init__(self, base_url: str = "http://localhost:8080/v1", 
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
    
    def health_check(self) -> Dict[str, Any]:
        """Check server health"""
        response = self.session.get(
            f"{self.base_url}/health",
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()
    
    def list_models(self) -> Dict[str, ModelMetadata]:
        """List available models"""
        response = self.session.get(
            f"{self.base_url}/models",
            timeout=self.timeout
        )
        response.raise_for_status()
        data = response.json()
        
        # Convert to ModelMetadata objects
        models = {}
        for name, metadata in data.items():
            models[name] = ModelMetadata(**metadata)
        
        return models
    
    def list_instances(self) -> List[Dict[str, Any]]:
        """List model instances"""
        response = self.session.get(
            f"{self.base_url}/models/instances",
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()
    
    def create_instance(self, model_name: str, 
                       initial_state: Optional[Dict[str, Any]] = None) -> ModelInstance:
        """Create a new model instance"""
        payload = {
            "model_name": model_name,
            "initial_state": initial_state or {}
        }
        
        response = self.session.post(
            f"{self.base_url}/models/instances",
            json=payload,
            timeout=self.timeout
        )
        response.raise_for_status()
        return ModelInstance(**response.json())
    
    def delete_instance(self, instance_id: Union[str, UUID]) -> Dict[str, Any]:
        """Delete a model instance"""
        instance_id = str(instance_id)
        
        response = self.session.delete(
            f"{self.base_url}/models/instances/{instance_id}",
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()
    
    def infer(self, instance_id: Union[str, UUID], 
              data: Dict[str, Any],
              parameters: Optional[Dict[str, Any]] = None,
              request_id: Optional[Union[str, UUID]] = None) -> InferenceResponse:
        """Run inference on a model instance"""
        instance_id = str(instance_id)
        
        payload = {
            "data": data,
            "parameters": parameters or {},
        }
        
        if request_id:
            payload["request_id"] = str(request_id)
        
        response = self.session.post(
            f"{self.base_url}/models/instances/{instance_id}/infer",
            json=payload,
            timeout=self.timeout
        )
        response.raise_for_status()
        return InferenceResponse(**response.json())
    
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
    
    # Check health
    health = client.health_check()
    print(f"Server health: {health}")
    
    # List models
    models = client.list_models()
    print(f"Available models: {list(models.keys())}")
    
    # Create instance
    instance = client.create_instance("beta_bernoulli")
    print(f"Created instance: {instance.id}")
    
    # Run inference
    data = {
        "y": [1, 0, 1, 1, 0, 1, 1, 1, 0, 1]
    }
    
    result = client.infer(instance.id, data)
    print(f"Inference completed in {result.duration_ms:.2f}ms")
    print(f"Results: {result.results}")