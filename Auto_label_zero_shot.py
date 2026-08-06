#!/usr/bin/env python3
import os
import cv2
from pathlib import Path
from tqdm import tqdm
from PIL import Image

# Import your existing zero-shot engine
from zero_shot_classifier import load_model, classify_pil_image, CLASSES

# Configuration
CLEAN_FRAMES_DIR = r"D:\BeeGuard_Videos\Clean_Frames"
OUTPUT_LABELS_DIR = r"D:\BeeGuard_Videos\cvat_export_corrected\obj_train_data"
os.makedirs(OUTPUT_LABELS_DIR, exist_ok=True)

# Create a mapping to lock the zero-shot class names to consistent YOLO IDs
CLASS_TO_ID = {name: idx for idx, name in enumerate(CLASSES.keys())}

def main():
    print(f"Loading Zero-Shot model... (This may take a moment)")
    processor, model = load_model()
    
    # Get all images
    images = [f for f in os.listdir(CLEAN_FRAMES_DIR) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
    print(f"Found {len(images)} images to auto-label.")

    for img_name in tqdm(images):
        img_path = os.path.join(CLEAN_FRAMES_DIR, img_name)
        base_name = os.path.splitext(img_name)[0]
        label_path = os.path.join(OUTPUT_LABELS_DIR, base_name + ".txt")

        try:
            pil_img = Image.open(img_path).convert("RGB")
            result = classify_pil_image(pil_img, processor, model)
            
            lines = []
            img_w, img_h = pil_img.size

            # Loop through all detections
            for cls_name, box, score, raw_label in result['all_detections']:
                if score < 0.3: # Only keep high-confidence detections for automatic labels
                    continue
                
                x0, y0, x1, y1 = box
                
                # Convert to YOLO normalized format (center_x, center_y, width, height)
                center_x = (x0 + x1) / 2.0 / img_w
                center_y = (y0 + y1) / 2.0 / img_h
                width = (x1 - x0) / img_w
                height = (y1 - y0) / img_h
                
                if cls_name in CLASS_TO_ID:
                    class_id = CLASS_TO_ID[cls_name]
                    lines.append(f"{class_id} {center_x:.6f} {center_y:.6f} {width:.6f} {height:.6f}")

            # Write to the txt file
            with open(label_path, "w") as f:
                if lines:
                    f.write("\n".join(lines) + "\n")
                    
        except Exception as e:
            print(f"Error processing {img_name}: {e}")

    print(f"Done! Labels saved to {OUTPUT_LABELS_DIR}. Zip this folder to import into CVAT.")

if __name__ == "__main__":
    main()