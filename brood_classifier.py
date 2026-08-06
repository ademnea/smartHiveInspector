#!/usr/bin/env python3
"""
Brood/Frame Stage Classifier — ORB Feature Matching (OpenCV, no internet, no deep learning)

Given a folder of reference "template" images organized by category
(templates/<category>/*.png) and a test photo, this script scores how
strongly the test photo resembles each category and reports the best match(es).

Why ORB feature matching instead of raw template matching:
Raw cv2.matchTemplate needs the target to be nearly the same scale/rotation/
lighting as the template. Real bee photos vary a lot in zoom and angle, so we
use ORB (Oriented FAST + Rotated BRIEF) keypoint descriptors, which are robust
to rotation and reasonably robust to scale/lighting changes, then match them
with a brute-force Hamming matcher + Lowe's ratio test to filter out noise.

Usage:
    python3 brood_classifier.py <test_image_path> [--templates-dir DIR] [--out DIR]

Example:
    python3 brood_classifier.py test_photos/frame1.jpg
"""

import argparse
import os
import sys
from pathlib import Path

import cv2
import numpy as np


# ---- Tunable parameters -----------------------------------------------
ORB_FEATURES = 1500          # number of keypoints ORB tries to find per image
LOWE_RATIO = 0.75            # Lowe's ratio test threshold (lower = stricter)
MIN_GOOD_MATCHES = 8         # below this, we don't trust the match at all
RESIZE_MAX_DIM = 1200        # downscale huge photos for speed/consistency
# -------------------------------------------------------------------------


def load_and_prep(path):
    """Load an image in grayscale and resize so its longest side is capped."""
    img = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
    if img is None:
        raise ValueError(f"Could not read image: {path}")
    h, w = img.shape[:2]
    scale = RESIZE_MAX_DIM / max(h, w)
    if scale < 1.0:
        img = cv2.resize(img, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
    return img


def build_template_database(templates_dir):
    """
    Walk templates_dir/<category>/*.png|jpg and compute ORB descriptors
    for every template image. Returns:
        { category: [ (filename, keypoints, descriptors, shape), ... ] }
    """
    orb = cv2.ORB_create(nfeatures=ORB_FEATURES)
    db = {}
    templates_dir = Path(templates_dir)

    if not templates_dir.exists():
        raise FileNotFoundError(f"Templates directory not found: {templates_dir}")

    for category_dir in sorted(templates_dir.iterdir()):
        if not category_dir.is_dir():
            continue
        entries = []
        for img_path in sorted(category_dir.glob("*")):
            if img_path.suffix.lower() not in (".png", ".jpg", ".jpeg", ".bmp"):
                continue
            img = load_and_prep(img_path)
            kp, des = orb.detectAndCompute(img, None)
            if des is None or len(kp) == 0:
                print(f"  [warn] no features found in {img_path.name}, skipping")
                continue
            entries.append((img_path.name, kp, des, img.shape))
        if entries:
            db[category_dir.name] = entries
        else:
            print(f"  [warn] category '{category_dir.name}' has no usable templates")

    return db, orb


def score_against_template(des_test, des_template):
    """
    Brute-force Hamming match between two ORB descriptor sets, filtered
    by Lowe's ratio test. Returns the count of "good" matches.
    """
    if des_template is None or des_test is None:
        return 0
    if len(des_template) < 2 or len(des_test) < 2:
        return 0

    bf = cv2.BFMatcher(cv2.NORM_HAMMING)
    matches = bf.knnMatch(des_test, des_template, k=2)

    good = []
    for pair in matches:
        if len(pair) != 2:
            continue
        m, n = pair
        if m.distance < LOWE_RATIO * n.distance:
            good.append(m)
    return good


def classify(test_path, templates_dir, out_dir=None):
    orb = cv2.ORB_create(nfeatures=ORB_FEATURES)
    print(f"Loading templates from: {templates_dir}")
    db, _ = build_template_database(templates_dir)

    if not db:
        print("No templates loaded — nothing to compare against.")
        return

    print(f"\nLoaded categories: {list(db.keys())}")
    for cat, entries in db.items():
        print(f"  {cat}: {len(entries)} template(s)")

    print(f"\nAnalyzing test image: {test_path}")
    test_img = load_and_prep(test_path)
    kp_test, des_test = orb.detectAndCompute(test_img, None)

    if des_test is None:
        print("Could not extract features from the test image (too blurry/uniform?).")
        return

    print(f"Found {len(kp_test)} keypoints in test image.\n")

    results = {}
    best_per_category = {}

    for category, entries in db.items():
        best_count = 0
        best_entry = None
        best_matches = None
        for fname, kp_tpl, des_tpl, shape in entries:
            good = score_against_template(des_test, des_tpl)
            count = len(good)
            if count > best_count:
                best_count = count
                best_entry = (fname, kp_tpl, shape)
                best_matches = good
        results[category] = best_count
        best_per_category[category] = (best_entry, best_matches)

    # Rank categories by best match count
    ranked = sorted(results.items(), key=lambda kv: kv[1], reverse=True)

    print("=== Match scores by category (higher = more visual similarity) ===")
    for cat, count in ranked:
        flag = "  <-- best match" if cat == ranked[0][0] else ""
        confidence = "confident" if count >= MIN_GOOD_MATCHES else "weak/uncertain"
        print(f"  {cat:28s} good_matches={count:4d}   ({confidence}){flag}")

    top_cat, top_count = ranked[0]
    print()
    if top_count < MIN_GOOD_MATCHES:
        print(f"No category reached the minimum confidence threshold "
              f"({MIN_GOOD_MATCHES} good matches). Best guess is '{top_cat}' "
              f"but treat this as inconclusive.")
    else:
        print(f"Best match: '{top_cat}' with {top_count} good feature matches.")

    # Optional: save a visual of the best match for sanity-checking
    if out_dir:
        out_dir = Path(out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        entry, matches = best_per_category[top_cat]
        if entry and matches:
            fname, kp_tpl, shape = entry
            tpl_img_path = Path(templates_dir) / top_cat / fname
            tpl_img = load_and_prep(tpl_img_path)
            vis = cv2.drawMatches(
                test_img, kp_test, tpl_img, kp_tpl, matches[:40], None,
                flags=cv2.DrawMatchesFlags_NOT_DRAW_SINGLE_POINTS
            )
            out_path = out_dir / f"match_{Path(test_path).stem}_vs_{top_cat}.png"
            cv2.imwrite(str(out_path), vis)
            print(f"\nSaved match visualization to: {out_path}")

    return ranked


def main():
    parser = argparse.ArgumentParser(description="Classify a bee frame photo against reference templates.")
    parser.add_argument("test_image", help="Path to the photo you want to classify")
    parser.add_argument("--templates-dir", default="templates", help="Root folder of category subfolders")
    parser.add_argument("--out", default="results", help="Folder to save match visualization")
    parser.add_argument("--show", action="store_true",
                         help="Pop up a window showing the match visualization (press any key to close)")
    args = parser.parse_args()

    if not os.path.exists(args.test_image):
        print(f"Error: test image not found: {args.test_image}")
        sys.exit(1)

    ranked = classify(args.test_image, args.templates_dir, args.out)

    if args.show and ranked:
        top_cat = ranked[0][0]
        out_path = Path(args.out) / f"match_{Path(args.test_image).stem}_vs_{top_cat}.png"
        if out_path.exists():
            vis = cv2.imread(str(out_path))
            cv2.imshow(f"Best match: {top_cat} (press any key to close)", vis)
            cv2.waitKey(0)
            cv2.destroyAllWindows()
        else:
            print(f"[note] No visualization file found to display ({out_path}); "
                  f"this can happen if match count was 0.")


if __name__ == "__main__":
    main()