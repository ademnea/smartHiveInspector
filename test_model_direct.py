#!/usr/bin/env python3
import sys
from ultralytics import YOLO

MODEL_PATH = r"D:\BeeGuard_Videos\model_files\best.pt"

if len(sys.argv) < 2:
    print("Usage: python test_model_direct.py <path_to_image>")
    sys.exit(1)

image_path = sys.argv[1]

print(f"Loading model from: {MODEL_PATH}")
model = YOLO(MODEL_PATH)

print("Model's class names (as baked into this .pt file):")
for idx, name in model.names.items():
    print(f"  {idx}: {name}")

print(f"\nRunning inference on: {image_path}")
results = model(image_path, conf=0.01, verbose=False)

boxes = results[0].boxes
print(f"\n{len(boxes)} raw box(es) found (conf >= 0.01, unfiltered):\n")

if len(boxes) == 0:
    print("Literally zero boxes at any confidence level.")
else:
    for box in sorted(boxes, key=lambda b: -float(b.conf[0])):
        cls_id = int(box.cls[0].item())
        conf = float(box.conf[0].item())
        cls_name = model.names[cls_id]
        print(f"  • {cls_name}: {conf:.4f}")