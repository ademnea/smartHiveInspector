"""
BeeGuard - Round 2: train on your CVAT corrections, then auto-label
the remaining frames much more accurately than the zero-shot pass.

Workflow this expects:
  1. You ran auto_label_zero_shot.py and uploaded pre-labels to CVAT.
  2. You reviewed/fixed a batch of frames in CVAT (doesn't need to be
     all 1,424 - even 150-300 corrected frames is a useful start).
  3. Export that task from CVAT as "YOLO 1.1" -> gives you a folder
     with images/ + labels/ + obj.names, matching this script's
     CORRECTED_DATASET_DIR below.
  4. This script fine-tunes a small YOLOv8 model on that corrected set,
     then runs it over every remaining (not-yet-labeled) frame to
     produce a fresh, better round of pre-labels. Re-import to CVAT,
     review again, repeat if needed (accuracy improves each round).

INSTALL (one time):
    pip install ultralytics

RUN:
    python retrain_yolo_from_corrections.py
"""

import os
import shutil
import random
import yaml
from ultralytics import YOLO

# ------------------------------------------------------------------
# CONFIG - edit these to match your setup
# ------------------------------------------------------------------
# Folder exported from CVAT (YOLO 1.1 format) after you corrected a batch
CORRECTED_DATASET_DIR = r"D:\BeeGuard_Videos\cvat_export_corrected"

# All cleaned frames (from remove_duplicates.py output)
ALL_FRAMES_DIR = r"D:\BeeGuard_Videos\Clean_Frames"

# Where the new, better round of auto-labels should go
NEW_LABELS_OUTPUT = r"D:\BeeGuard_Videos\cvat_import_round2"

CLASS_NAMES = [
    "capped_brood",
    "Drone_bee_capped_brood",
    "healthy_brood_pattern",
    "eggs",
    "larvae",
    "queen_bee",
]

EPOCHS = 80
IMG_SIZE = 960          # brood cells are small, keep resolution decent
BASE_MODEL = "yolov8s.pt"   # small model = fast, good enough for a first real model
CONFIDENCE_THRESHOLD = 0.25

WORKDIR = r"D:\BeeGuard_Videos\yolo_workdir"

# ------------------------------------------------------------------


def prepare_yolo_dataset():
    """Turn the CVAT YOLO export into the folder layout Ultralytics expects
    (images/train, images/val, labels/train, labels/val) with a 90/10 split."""
    images_src = os.path.join(CORRECTED_DATASET_DIR, "obj_train_data")
    if not os.path.isdir(images_src):
        # some CVAT exports put images alongside labels directly
        images_src = CORRECTED_DATASET_DIR

    all_images = [f for f in os.listdir(images_src) if f.lower().endswith((".jpg", ".jpeg", ".png"))]
    random.seed(42)
    random.shuffle(all_images)

    split_idx = max(1, int(len(all_images) * 0.9))
    train_imgs = all_images[:split_idx]
    val_imgs = all_images[split_idx:] or all_images[:1]  # guarantee at least 1 val image

    for split_name, split_files in [("train", train_imgs), ("val", val_imgs)]:
        img_out = os.path.join(WORKDIR, "images", split_name)
        lbl_out = os.path.join(WORKDIR, "labels", split_name)
        os.makedirs(img_out, exist_ok=True)
        os.makedirs(lbl_out, exist_ok=True)

        for img_name in split_files:
            base = os.path.splitext(img_name)[0]
            src_img = os.path.join(images_src, img_name)
            src_lbl = os.path.join(images_src, base + ".txt")

            shutil.copy2(src_img, os.path.join(img_out, img_name))
            if os.path.exists(src_lbl):
                shutil.copy2(src_lbl, os.path.join(lbl_out, base + ".txt"))
            else:
                open(os.path.join(lbl_out, base + ".txt"), "w").close()

    data_yaml_path = os.path.join(WORKDIR, "data.yaml")
    with open(data_yaml_path, "w") as f:
        yaml.dump({
            "path": WORKDIR,
            "train": "images/train",
            "val": "images/val",
            "names": {i: name for i, name in enumerate(CLASS_NAMES)},
        }, f)

    print(f"Prepared {len(train_imgs)} train / {len(val_imgs)} val images at {WORKDIR}")
    return data_yaml_path


def train(data_yaml_path):
    model = YOLO(BASE_MODEL)
    model.train(
        data=data_yaml_path,
        epochs=EPOCHS,
        imgsz=IMG_SIZE,
        patience=20,
        project=WORKDIR,
        name="beeguard_model",
    )
    best_weights = os.path.join(WORKDIR, "beeguard_model", "weights", "best.pt")
    print(f"Trained model saved at: {best_weights}")
    return best_weights


def already_labeled_frames():
    images_src = os.path.join(CORRECTED_DATASET_DIR, "obj_train_data")
    if not os.path.isdir(images_src):
        images_src = CORRECTED_DATASET_DIR
    return {f for f in os.listdir(images_src) if f.lower().endswith((".jpg", ".jpeg", ".png"))}


def auto_label_remaining(best_weights):
    os.makedirs(NEW_LABELS_OUTPUT, exist_ok=True)
    labels_dir = os.path.join(NEW_LABELS_OUTPUT, "obj_train_data")
    os.makedirs(labels_dir, exist_ok=True)

    with open(os.path.join(NEW_LABELS_OUTPUT, "obj.names"), "w") as f:
        f.write("\n".join(CLASS_NAMES) + "\n")

    model = YOLO(best_weights)
    done = already_labeled_frames()

    remaining = [
        f for f in sorted(os.listdir(ALL_FRAMES_DIR))
        if f.lower().endswith((".jpg", ".jpeg", ".png")) and f not in done
    ]
    print(f"Auto-labeling {len(remaining)} remaining frames with the fine-tuned model...")

    train_list_path = os.path.join(NEW_LABELS_OUTPUT, "train.txt")
    with open(train_list_path, "w") as train_list:
        for image_name in remaining:
            img_path = os.path.join(ALL_FRAMES_DIR, image_name)
            results = model.predict(img_path, conf=CONFIDENCE_THRESHOLD, verbose=False)[0]

            base_name = os.path.splitext(image_name)[0]
            label_path = os.path.join(labels_dir, base_name + ".txt")

            lines = []
            for box in results.boxes:
                cls_id = int(box.cls.item())
                x, y, w, h = box.xywhn[0].tolist()  # already normalized
                lines.append(f"{cls_id} {x:.6f} {y:.6f} {w:.6f} {h:.6f}")

            with open(label_path, "w") as lf:
                if lines:
                    lf.write("\n".join(lines) + "\n")

            train_list.write(f"obj_train_data/{image_name}\n")

    print(f"New round of labels written to: {NEW_LABELS_OUTPUT}")
    print("Zip that folder and upload to CVAT (format: YOLO 1.1) for your next review pass.")


def main():
    data_yaml_path = prepare_yolo_dataset()
    best_weights = train(data_yaml_path)
    auto_label_remaining(best_weights)


if __name__ == "__main__":
    main()