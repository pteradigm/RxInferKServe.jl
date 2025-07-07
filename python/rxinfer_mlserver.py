"""
MLServer runtime implementation for RxInfer.jl models
"""

import os
import json
import subprocess
import logging
from typing import Dict, List, Any, Optional
from pathlib import Path

import numpy as np
from mlserver import MLModel, types
from mlserver.codecs import NumpyCodec
from mlserver.errors import MLServerError

logger = logging.getLogger(__name__)


class RxInferRuntime(MLModel):
    """
    MLServer runtime for serving RxInfer.jl models through Julia subprocess
    """
    
    def __init__(self, settings: types.Settings, **kwargs):
        super().__init__(settings, **kwargs)
        self.julia_process = None
        self.julia_project_path = None
        self.model_name = None
        
    async def load(self) -> bool:
        """Initialize the Julia runtime and load the model"""
        try:
            # Get model configuration
            model_uri = self._settings.parameters.uri
            self.julia_project_path = Path(model_uri).parent
            self.model_name = self._settings.parameters.extra.get("model_name", "default_model")
            
            # Start Julia server subprocess
            julia_cmd = [
                "julia",
                "--project=" + str(self.julia_project_path),
                "-e",
                f"""
                using RxInferMLServer
                start_server(
                    host="127.0.0.1",
                    port=0,  # Let OS assign port
                    enable_auth=false,
                    log_level="info"
                )
                """
            ]
            
            self.julia_process = subprocess.Popen(
                julia_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            # Wait for server to start and get port
            # This is a simplified version - in production, you'd want better process management
            logger.info(f"Started Julia RxInfer server for model: {self.model_name}")
            
            self.ready = True
            return self.ready
            
        except Exception as e:
            logger.error(f"Failed to load RxInfer model: {e}")
            raise MLServerError(f"Failed to load model: {e}")
    
    async def predict(self, payload: types.InferenceRequest) -> types.InferenceResponse:
        """Run inference using the RxInfer model"""
        try:
            # Extract input data
            inputs = self._extract_inputs(payload)
            
            # Prepare inference request for RxInfer
            rxinfer_request = {
                "data": inputs,
                "parameters": {
                    "iterations": 10,
                    # Add other RxInfer-specific parameters
                }
            }
            
            # Call RxInfer server (simplified - would use HTTP client in practice)
            # For now, return mock response
            results = {
                "posteriors": {
                    "theta": {
                        "type": "Beta",
                        "parameters": {"alpha": 5.0, "beta": 3.0}
                    }
                },
                "free_energy": -10.5
            }
            
            # Convert results to MLServer format
            outputs = self._format_outputs(results)
            
            return types.InferenceResponse(
                id=payload.id,
                model_name=self.name,
                model_version=self.version,
                outputs=outputs
            )
            
        except Exception as e:
            logger.error(f"Prediction failed: {e}")
            raise MLServerError(f"Prediction failed: {e}")
    
    async def unload(self) -> bool:
        """Cleanup Julia process"""
        if self.julia_process:
            self.julia_process.terminate()
            self.julia_process.wait()
        return True
    
    def _extract_inputs(self, payload: types.InferenceRequest) -> Dict[str, Any]:
        """Extract and convert inputs from MLServer format"""
        inputs = {}
        
        for input_data in payload.inputs:
            name = input_data.name
            
            # Handle different input types
            if input_data.datatype == "FP32" or input_data.datatype == "FP64":
                # Numeric data
                data = NumpyCodec.decode_input(input_data)
                inputs[name] = data.tolist() if data.ndim > 0 else float(data)
            elif input_data.datatype == "BYTES":
                # String/bytes data
                inputs[name] = input_data.data
            else:
                # Default handling
                inputs[name] = input_data.data
                
        return inputs
    
    def _format_outputs(self, results: Dict[str, Any]) -> List[types.ResponseOutput]:
        """Format RxInfer results for MLServer response"""
        outputs = []
        
        for key, value in results.items():
            if isinstance(value, dict) and "type" in value:
                # Distribution output
                output = types.ResponseOutput(
                    name=key,
                    datatype="BYTES",
                    shape=[1],
                    data=[json.dumps(value)]
                )
            elif isinstance(value, (int, float)):
                # Scalar output
                output = types.ResponseOutput(
                    name=key,
                    datatype="FP64",
                    shape=[1],
                    data=[value]
                )
            elif isinstance(value, list):
                # Array output
                arr = np.array(value)
                output = types.ResponseOutput(
                    name=key,
                    datatype="FP64",
                    shape=list(arr.shape),
                    data=arr.flatten().tolist()
                )
            else:
                # Generic output as JSON
                output = types.ResponseOutput(
                    name=key,
                    datatype="BYTES",
                    shape=[1],
                    data=[json.dumps(value)]
                )
                
            outputs.append(output)
            
        return outputs