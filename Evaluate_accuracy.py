#!/usr/bin/env python3
"""
Batch accuracy checker for brood_classifier.py

Your Clean_Frames folder already has filenames that describe what's in each
photo (e.g. "Capped Drone Brood in February_00001.jpg"). This script uses
those filenames as ground-truth labels, runs the ORB classifier on every
matching photo, and reports how often it got the right answer — a real
accuracy percentage instead of eyeballing one photo at a time.

HOW GROUND TRUTH IS INFERRED FROM FILENAMES:
Edit the FILENAME_RULES list below to match your naming conventions.
Each rule is (substring_to_look_for, category_name). The first matching
substring (case-insensitive) wins. Add more rules as your naming evolves.

Usage:
    python evaluate_accuracy.py --frames-dir Clean_Frames --templates-dir templates
"""

import argparse
import sys
from pathlib import Path
from collections import defaultdict

import cv2

from brood_classifier import build_template_database, score_against_template, load_and_prep, MIN_GOOD_MATCHES

# ---- Map filename substrings -> category folder names ----------------
# IMPORTANT: order matters — more specific rules should come first.
FILENAME_RULES = [
    ("capped drone brood", "drone_capped_brood"),
    ("drone brood", "drone_capped_brood"),
    ("capped brood", "capped_brood"),
    ("eggs larva and capped brood", None),   # multi-subject photo — see note below
    ("eggs", "eggs"),
    ("larva", "larvae"),
    ("larvae", "larvae"),
    ("queen", "queen_bee"),
    ("healthy brood pattern", "healthy_brood_pattern"),
    ("brood pattern", "healthy_brood_pattern"),
]
# Note: filenames matching a None category (like generic multi-subject stock
# photos showing eggs+larvae+capped brood all at once) are SKIPPED from
# scoring, since there's no single correct category to check against —
# they're flagged separately so you know they exist.
# -------------------------------------------------------------------------


def infer_label_from_filename(filename):
    name_lower = filename.lower()
    for substring, category in FILENAME_RULES:
        if substring in name_lower:
            return category  # may be None (ambiguous/multi-subject)
    return "UNKNOWN"  # no rule matched at all


def evaluate(frames_dir, templates_dir, orb_features=1500):
    print(f"Loading templates from: {templates_dir}")
    db, orb = build_template_database(templates_dir)
    if not db:
        print("No templates loaded — nothing to evaluate against.")
        return

    frames_dir = Path(frames_dir)
    image_paths = [p for p in sorted(frames_dir.glob("*"))
                   if p.suffix.lower() in (".jpg", ".jpeg", ".png", ".bmp")]

    if not image_paths:
        print(f"No images found in {frames_dir}")
        return

    print(f"Found {len(image_paths)} images in {frames_dir}\n")

    correct = 0
    total_scored = 0
    skipped_ambiguous = 0
    skipped_unknown = 0
    confusion = defaultdict(lambda: defaultdict(int))  # confusion[true][predicted] += 1
    misses = []

    for img_path in image_paths:
        true_label = infer_label_from_filename(img_path.name)

        if true_label is None:
            skipped_ambiguous += 1
            continue
        if true_label == "UNKNOWN":
            skipped_unknown += 1
            continue
        if true_label not in db:
            # ground truth points to a category with no templates loaded
            skipped_unknown += 1
            continue

        test_img = load_and_prep(img_path)
        kp_test, des_test = orb.detectAndCompute(test_img, None)
        if des_test is None:
            skipped_unknown += 1
            continue

        best_cat, best_count = None, -1
        for category, entries in db.items():
            cat_best = 0
            for fname, kp_tpl, des_tpl, shape in entries:
                good = score_against_template(des_test, des_tpl)
                cat_best = max(cat_best, len(good))
            if cat_best > best_count:
                best_count = cat_best
                best_cat = category

        total_scored += 1
        confusion[true_label][best_cat] += 1

        if best_cat == true_label and best_count >= MIN_GOOD_MATCHES:
            correct += 1
        else:
            misses.append((img_path.name, true_label, best_cat, best_count))

    # ---- Report ----
    print("=" * 70)
    print("ACCURACY REPORT")
    print("=" * 70)
    if total_scored == 0:
        print("No images could be scored (check FILENAME_RULES match your filenames).")
        return

    acc = 100.0 * correct / total_scored
    print(f"Scored images:        {total_scored}")
    print(f"Correct predictions:  {correct}")
    print(f"Accuracy:             {acc:.1f}%")
    print(f"Skipped (ambiguous/multi-subject filenames): {skipped_ambiguous}")
    print(f"Skipped (no matching rule or no template):   {skipped_unknown}")

    print("\n--- Confusion matrix (rows = true label, cols = predicted) ---")
    all_cats = sorted(set(list(confusion.keys()) + [c for d in confusion.values() for c in d.keys()]))
    header = "true\\pred".ljust(24) + "".join(c[:12].ljust(14) for c in all_cats)
    print(header)
    for true_cat in all_cats:
        row = true_cat.ljust(24)
        for pred_cat in all_cats:
            row += str(confusion[true_cat].get(pred_cat, 0)).ljust(14)
        print(row)

    if misses:
        print(f"\n--- Misclassified files ({len(misses)}) ---")
        for fname, true_cat, pred_cat, count in misses[:30]:
            print(f"  {fname:50s} true={true_cat:20s} predicted={pred_cat:20s} (matches={count})")
        if len(misses) > 30:
            print(f"  ... and {len(misses) - 30} more")


def main():
    parser = argparse.ArgumentParser(description="Evaluate classifier accuracy using filename-based ground truth.")
    parser.add_argument("--frames-dir", default="Clean_Frames", help="Folder of labeled photos to test against")
    parser.add_argument("--templates-dir", default="templates", help="Root folder of category subfolders")
    args = parser.parse_args()
    evaluate(args.frames_dir, args.templates_dir)


if __name__ == "__main__":
    main()