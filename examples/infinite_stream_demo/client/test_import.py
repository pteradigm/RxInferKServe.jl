#!/usr/bin/env python3
import sys
import os

print("=== Python Import Debug ===")
print(f"Python version: {sys.version}")
print(f"Current directory: {os.getcwd()}")
print(f"Directory contents: {os.listdir('.')}")
print(f"Python path: {sys.path}")

# Check proto directory
if os.path.exists('proto'):
    print(f"\nProto directory exists!")
    print(f"Proto contents: {os.listdir('proto')}")
else:
    print("\nProto directory NOT FOUND!")

# Try different import methods
print("\n=== Testing imports ===")

# Method 1: Direct sys.path
sys.path.insert(0, '/app/proto')
try:
    import inference_pb2
    print("✓ Method 1 worked: sys.path.insert(0, '/app/proto')")
except ImportError as e:
    print(f"✗ Method 1 failed: {e}")

# Method 2: Relative import
sys.path.insert(0, os.path.join(os.getcwd(), 'proto'))
try:
    import inference_pb2
    print("✓ Method 2 worked: sys.path with relative proto")
except ImportError as e:
    print(f"✗ Method 2 failed: {e}")