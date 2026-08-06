

#!/usr/bin/env python3
"""
Train a custom YOLO model on your 6-class hive-frame dataset.

Prereqs (run once):
    pip install ultralytics

Folder layout expected (see data.yaml):
    D:/BeeGuard_Videos/yolo_dataset/
        images/train/*.jpg
        images/val/*.jpg
        labels/train/*.txt
        labels/val/*.txt

Each labels/*.txt line is YOLO format:
    <class_id> <x_center> <y_center> <width> <height>   (all normalized 0-1)

Usage:
    python3 train.py
    python3 train.py --model yolo11s.pt --epochs 150 --imgsz 960
"""

import argparse
from ultralytics import YOLO


def main():
    parser = argparse.ArgumentParser(description="Train the BeeGuard custom YOLO model.")
    parser.add_argument("--data", default="data.yaml", help="Path to data.yaml")
    parser.add_argument("--model", default="yolo11s.pt",
                         help="Base pretrained checkpoint to fine-tune from. "
                              "yolo11n.pt = fastest/smallest, yolo11s.pt = good balance, "
                              "yolo11m.pt = more accurate but slower.")
    parser.add_argument("--epochs", type=int, default=150)
    parser.add_argument("--imgsz", type=int, default=960,
                         help="Comb cells are small relative to the frame, so a larger "
                              "image size than the YOLO default (640) helps a lot here.")
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--patience", type=int, default=30,
                         help="Early stopping patience (epochs with no val improvement).")
    parser.add_argument("--project", default="beeguard_model")
    parser.add_argument("--name", default="train")
    parser.add_argument("--device", default="0", help="'0' for first GPU, 'cpu' for CPU")
    args = parser.parse_args()

    model = YOLO(args.model)

    model.train(
        data=args.data,
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        patience=args.patience,
        device=args.device,
        project=args.project,
        name=args.name,
        # Small-object friendly augmentation tweaks:
        mosaic=1.0,
        scale=0.5,
        degrees=10.0,
        fliplr=0.5,
        flipud=0.0,
        hsv_h=0.015,
        hsv_s=0.5,
        hsv_v=0.3,
    )

    # Run validation on the best checkpoint and print per-class metrics
    best_model = YOLO(f"{args.project}/{args.name}/weights/best.pt")
    metrics = best_model.val(data=args.data, imgsz=args.imgsz, device=args.device)
    print("\nPer-class mAP50-95:")
    for cls_id, ap in zip(metrics.box.ap_class_index, metrics.box.ap50):
        print(f"  {best_model.names[cls_id]:28s} mAP50={ap:.3f}")

    print(f"\nBest weights saved to: {args.project}/{args.name}/weights/best.pt")
    print("Point CUSTOM_MODEL_PATH in app.py at this file when you're ready to deploy it.")


if __name__ == "__main__":
    main()