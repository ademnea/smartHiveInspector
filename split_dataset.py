#!/usr/bin/env python3
"""
Split a flat folder of images + YOLO .txt labels into images/train, images/val,
labels/train, labels/val — the layout data.yaml expects.

Usage:
    python3 split_dataset.py --src D:/BeeGuard_Videos/annotated --dst D:/BeeGuard_Videos/yolo_dataset --val-frac 0.15

Expects --src to contain:
    image1.jpg  image1.txt
    image2.jpg  image2.txt
    ...
(this is exactly what CVAT/Roboflow "YOLO" export gives you, flattened into one folder)
"""

import argparse
import random
import shutil
from pathlib import Path

IMG_EXTS = {".jpg", ".jpeg", ".png", ".bmp"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--src", required=True, help="Folder with flat images + matching .txt labels")
    parser.add_argument("--dst", required=True, help="Output root (matches `path:` in data.yaml)")
    parser.add_argument("--val-frac", type=float, default=0.15)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    src = Path(args.src)
    dst = Path(args.dst)
    images = sorted([p for p in src.iterdir() if p.suffix.lower() in IMG_EXTS])

    if not images:
        print(f"No images found in {src}")
        return

    # Only keep images that actually have a matching label file
    paired = [(img, img.with_suffix(".txt")) for img in images]
    missing = [img.name for img, lbl in paired if not lbl.exists()]
    if missing:
        print(f"[warn] {len(missing)} image(s) have no matching .txt label and will be skipped:")
        for name in missing[:10]:
            print(f"    {name}")
        if len(missing) > 10:
            print(f"    ...and {len(missing) - 10} more")
    paired = [(img, lbl) for img, lbl in paired if lbl.exists()]

    random.seed(args.seed)
    random.shuffle(paired)

    n_val = max(1, int(len(paired) * args.val_frac))
    val_set = paired[:n_val]
    train_set = paired[n_val:]

    for split_name, split_data in [("train", train_set), ("val", val_set)]:
        img_out = dst / "images" / split_name
        lbl_out = dst / "labels" / split_name
        img_out.mkdir(parents=True, exist_ok=True)
        lbl_out.mkdir(parents=True, exist_ok=True)
        for img, lbl in split_data:
            shutil.copy2(img, img_out / img.name)
            shutil.copy2(lbl, lbl_out / lbl.name)

    print(f"Done. {len(train_set)} train / {len(val_set)} val images copied to {dst}")


if __name__ == "__main__":
    main()