#!/usr/bin/env python3
import io
import os
import numpy as np
import streamlit as st
from PIL import Image, ImageDraw, ImageFont
from ultralytics import YOLO

# ------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------
CUSTOM_MODEL_PATH = r"D:\BeeGuard_Videos\model_files\best.pt"

if os.path.exists(CUSTOM_MODEL_PATH):
    YOLO_MODEL_PATH = CUSTOM_MODEL_PATH
    USING_CUSTOM_MODEL = True
else:
    YOLO_MODEL_PATH = "yolov8n.pt"
    USING_CUSTOM_MODEL = False

YOLO_CLASSES = [
    "Capped_brood",
    "Drone_bee_Capped_brood",
    "Healthy_brood_pattern",
    "Eggs",
    "Larvae",
    "Queen_Bee",
]

DISPLAY_NAMES = {
    "Capped_brood": "Capped Brood",
    "Drone_bee_Capped_brood": "Drone Capped Brood",
    "Healthy_brood_pattern": "Healthy Brood Pattern",
    "Eggs": "Eggs",
    "Larvae": "Larvae",
    "Queen_Bee": "Queen Bee",
    "person": "Person",
    "cell phone": "Cell Phone",
}

CLASS_COLORS = {
    "Capped_brood": (91, 140, 220),
    "Drone_bee_Capped_brood": (231, 76, 60),
    "Healthy_brood_pattern": (46, 204, 113),
    "Eggs": (241, 196, 15),
    "Larvae": (155, 89, 182),
    "Queen_Bee": (230, 126, 34),
}

# Lowered per your request — helps surface small objects (Eggs, Larvae,
# Queen Bee) since precision is strong enough to afford more sensitivity.
# Tradeoff: at 0.10 you WILL see more false positives than at 0.15/0.25 —
# that's the price of catching more real small objects. If the app starts
# feeling noisy/cluttered, raise this back toward 0.15.
CONFIDENCE_THRESHOLD = 0.10

# Some classes need a stricter bar than the global default. Queen_Bee is the
# clearest case: a hive only ever has ONE queen, but with tiling now running
# every photo through many independent tile passes, even a small per-tile
# false-positive rate compounds into "detects a queen in almost every photo."
# Raising this class's own threshold cuts out the low-confidence spurious
# hits while keeping genuinely confident detections (validation showed
# Queen_Bee precision was strong at 0.96 — the problem lives at low
# confidence, not high).
PER_CLASS_MIN_CONFIDENCE = {
    "Queen_Bee": 0.55,
}

# Classes where only one instance is biologically expected per hive photo.
# If more than one candidate box clears the confidence bar, only the single
# highest-confidence one is kept — extras are treated as false positives,
# not additional queens.
SINGLETON_CLASSES = {"Queen_Bee"}

# Classes known to sometimes be confused with Larvae in this model version
# (Larvae had few clean training examples; some auto-labeled frames may have
# blurred the line with Capped_brood). Flag shaky low-confidence hits so a
# human double-checks before trusting them.
LARVAE_CONFUSION_RISK = {"Capped_brood", "Eggs"}
LARVAE_CONFUSION_CONF_CEILING = 0.45  # below this, flag as "verify visually"

# ------------------------------------------------------------------
# TILED INFERENCE — for "full frame" / zoomed-out photos
# ------------------------------------------------------------------
# The model was trained mostly on close-up crops where cells fill much of
# the frame. A wide shot of the whole wooden frame shrinks every cell down
# to a few pixels once resized for the model, so nothing gets detected.
# Slicing the photo into overlapping tiles and running detection on each
# tile at native resolution recreates the "close-up" scale the model
# actually knows, without retraining.
TILE_SIZE = 640
MIN_TILES_PER_SIDE = 2         # even a small image gets split into at least a
                                # 2x2 grid of tiles — this is what "zooms in"
                                # so per-cell boxes show up regardless of the
                                # original photo's resolution
DUPLICATE_IOU_THRESHOLD = 0.5  # boxes overlapping more than this (same class)
                                # are treated as the same object and merged


def compute_adaptive_tile_size(H, W, desired=TILE_SIZE, min_tiles_per_side=MIN_TILES_PER_SIDE):
    """
    Always tile, regardless of image size. For a large image, use the normal
    640px tile (several tiles, each near the model's trained scale). For a
    small image, shrink the tile size so it still gets split into at least
    min_tiles_per_side tiles per axis — each small crop then gets resized UP
    to the model's inference size, which is what lets it "zoom in" on
    individual cells even when the original photo isn't huge. Without this,
    small photos were going through a single, un-tiled pass and producing the
    oversized, low-confidence boxes you saw.
    """
    smallest_dim = min(H, W)
    if smallest_dim > desired:
        return desired
    forced_tile = max(smallest_dim // min_tiles_per_side, 64)
    return forced_tile


def tiled_detection(model, image_np, tile_size=TILE_SIZE, overlap=None, conf_threshold=0.05):
    """
    Runs the model tile-by-tile across a large image.

    image_np: HxWx3 numpy array (RGB)
    Returns a list of raw detections in FULL-IMAGE pixel coordinates:
        [x1, y1, x2, y2, conf, cls_id]

    Note: conf_threshold here is intentionally low (0.05) — we want the raw
    candidate pool before the app's real CONFIDENCE_THRESHOLD is applied
    later, so tiles near a boundary that only partially catch an object at
    lower confidence still get a chance to be merged with a better-confidence
    copy of the same object from a neighboring tile.
    """
    H, W = image_np.shape[:2]
    if overlap is None:
        overlap = max(int(tile_size * 0.25), 1)  # 25% overlap by default
    step = max(tile_size - overlap, 1)  # guard against overlap >= tile_size

    # Tiles get resized UP to this fixed size for inference, regardless of how
    # small the actual tile crop is — this is the "zoom in" step. A 200px
    # forced tile on a small photo gets upscaled to 640px before the model
    # sees it, same as a real 640px tile from a large photo would.
    inference_size = TILE_SIZE

    detections = []

    y = 0
    while y < H:
        y_end = min(y + tile_size, H)
        x = 0
        while x < W:
            x_end = min(x + tile_size, W)

            tile = image_np[y:y_end, x:x_end]
            results = model(tile, imgsz=inference_size, conf=conf_threshold, verbose=False)

            if len(results[0].boxes) > 0:
                for box in results[0].boxes:
                    cls_id = int(box.cls[0].item())
                    conf = float(box.conf[0].item())
                    xx1, yy1, xx2, yy2 = box.xyxy[0].tolist()
                    detections.append([xx1 + x, yy1 + y, xx2 + x, yy2 + y, conf, cls_id])

            if x_end >= W:
                break
            x += step
        if y_end >= H:
            break
        y += step

    return detections


def _iou(box_a, box_b):
    ax1, ay1, ax2, ay2 = box_a
    bx1, by1, bx2, by2 = box_b
    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax2, bx2), min(ay2, by2)
    if ix2 <= ix1 or iy2 <= iy1:
        return 0.0
    inter = (ix2 - ix1) * (iy2 - iy1)
    area_a = (ax2 - ax1) * (ay2 - ay1)
    area_b = (bx2 - bx1) * (by2 - by1)
    return inter / (area_a + area_b - inter + 1e-9)


def merge_duplicate_detections(detections, iou_threshold=DUPLICATE_IOU_THRESHOLD):
    """
    Real duplicate-removal step (this was imported but never actually used
    in the draft plan). Per-class greedy NMS: keeps the highest-confidence
    box, discards any other box of the SAME class that overlaps it more than
    iou_threshold — those are treated as the same object seen in overlapping
    tiles. Different classes are never merged with each other.

    detections: list of [x1, y1, x2, y2, conf, cls_id]
    Returns the same format, deduplicated.
    """
    if not detections:
        return []

    by_class = {}
    for det in detections:
        by_class.setdefault(det[5], []).append(det)

    kept = []
    for cls_id, dets in by_class.items():
        dets = sorted(dets, key=lambda d: d[4], reverse=True)
        while dets:
            best = dets.pop(0)
            kept.append(best)
            dets = [d for d in dets if _iou(best[:4], d[:4]) < iou_threshold]

    return kept


def apply_class_rules(merged_detections, model_names):
    """
    Applies two corrections on top of the raw merged detections, in pixel
    coordinates [x1, y1, x2, y2, conf, cls_id]:

    1. Per-class confidence overrides (e.g. Queen_Bee needs a stricter bar
       than the app's global threshold, since it's prone to low-confidence
       false positives).
    2. Singleton enforcement — for classes where only one instance is
       biologically expected (a hive has exactly one queen), keep only the
       single highest-confidence candidate and drop the rest as false
       positives rather than displaying multiple "queens."
    """
    filtered = []
    for det in merged_detections:
        cls_id = det[5]
        conf = det[4]
        cls_name = model_names[int(cls_id)]
        min_conf = PER_CLASS_MIN_CONFIDENCE.get(cls_name, CONFIDENCE_THRESHOLD)
        if conf >= min_conf:
            filtered.append(det)

    by_class = {}
    for det in filtered:
        by_class.setdefault(det[5], []).append(det)

    final = []
    for cls_id, dets in by_class.items():
        cls_name = model_names[int(cls_id)]
        if cls_name in SINGLETON_CLASSES:
            best = max(dets, key=lambda d: d[4])
            final.append(best)
        else:
            final.extend(dets)

    return final


st.set_page_config(page_title="BeeGuard", layout="centered", page_icon="🐝")


@st.cache_resource
def load_yolo_model():
    return YOLO(YOLO_MODEL_PATH)


def draw_boxes(pil_img, detections_list, model_names):
    img = pil_img.convert("RGB").copy()
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", size=max(14, img.width // 55))
    except Exception:
        font = ImageFont.load_default()

    sorted_dets = sorted(detections_list, key=lambda d: d[3] * d[4], reverse=True)

    for cls_id, x_center, y_center, w, h, conf in sorted_dets:
        if conf < CONFIDENCE_THRESHOLD:
            continue

        cls_name = model_names[int(cls_id)]
        color = CLASS_COLORS.get(cls_name, (200, 200, 200))
        display_name = DISPLAY_NAMES.get(cls_name, cls_name)

        x0 = int((x_center - w / 2) * img.width)
        y0 = int((y_center - h / 2) * img.height)
        x1 = int((x_center + w / 2) * img.width)
        y1 = int((y_center + h / 2) * img.height)

        draw.rectangle([x0, y0, x1, y1], outline=color, width=3)
        label = f"{display_name} {conf:.0%}"
        text_y = y0 - 18 if y0 - 18 > 0 else y0 + 2
        draw.rectangle([x0, text_y, x0 + len(label) * 7 + 6, text_y + 16], fill=color)
        draw.text((x0 + 3, text_y), label, fill=(255, 255, 255), font=font)
    return img


# ------------------------------------------------------------------
# HIVE HEALTH ASSESSMENT
# ------------------------------------------------------------------
HIVE_HEALTH_WEIGHTS = {
    "Queen_Bee": 2,
    "Eggs": 2,
    "Larvae": 1,
    "Healthy_brood_pattern": 2,
    "Capped_brood": 1,
    "Drone_bee_Capped_brood": 0,
}
MAX_HIVE_SCORE = sum(HIVE_HEALTH_WEIGHTS.values())  # 8


def assess_hive_health(detected_classes, using_custom_model):
    """
    Combine detected classes into a single Good Hive / Fair / Poor Hive
    verdict, along with the reasoning behind it.

    Returns: (verdict_label, color_hex, emoji, score, max_score, reasons)
    """
    if not using_custom_model:
        return (
            "Not Assessed",
            "#616161",
            "⚪",
            0,
            MAX_HIVE_SCORE,
            ["Custom hive model isn't loaded, so a health verdict can't be computed from generic detections."],
        )

    detected_set = set(detected_classes)
    score = sum(weight for cls, weight in HIVE_HEALTH_WEIGHTS.items() if cls in detected_set)

    reasons = []

    has_queen = "Queen_Bee" in detected_set
    has_eggs = "Eggs" in detected_set
    has_larvae = "Larvae" in detected_set
    has_healthy_pattern = "Healthy_brood_pattern" in detected_set
    has_capped = "Capped_brood" in detected_set
    has_drone_only = "Drone_bee_Capped_brood" in detected_set and not (
        has_capped or has_eggs or has_larvae or has_healthy_pattern
    )

    if has_queen:
        reasons.append("Queen Bee was spotted directly — strong sign the colony is queenright.")
    if has_eggs:
        reasons.append("Eggs are present, meaning a queen was laying within the last few days.")
    if has_larvae:
        reasons.append("Larvae are present, showing recent, ongoing brood development.")
    if has_healthy_pattern:
        reasons.append("A healthy brood pattern was detected, a strong indicator of good queen performance.")
    if has_capped:
        reasons.append("Capped brood is present, showing the colony has been rearing new bees.")
    if not has_queen and not has_eggs and not has_larvae:
        reasons.append("No queen, eggs, or larvae detected — no direct evidence of a currently active, laying queen.")
    if has_drone_only:
        reasons.append("Only drone brood was detected with no worker brood/eggs/larvae — this can point to a "
                        "failing queen or laying workers and should be treated as a caution flag.")
    if not detected_set:
        reasons.append("No hive resources were detected at all in this frame.")

    # Verdict thresholds (out of MAX_HIVE_SCORE = 8)
    if score >= 5:
        verdict, color, emoji = "Good Hive", "#1B5E20", "🟢"
    elif score >= 2:
        verdict, color, emoji = "Fair Hive / Needs Attention", "#E65100", "🟡"
    else:
        verdict, color, emoji = "Poor Hive", "#B71C1C", "🔴"

    return verdict, color, emoji, score, MAX_HIVE_SCORE, reasons


# ------------------------------------------------------------------
# STREAMLIT APP UI
# ------------------------------------------------------------------
st.title("🐝 Hive Inspection")

if not USING_CUSTOM_MODEL:
    st.warning(
        "⚠️ **Custom YOLO model not found.** Using a generic model for UI testing only "
        "— it will detect 'people' or 'cars', not hive cells. Point CUSTOM_MODEL_PATH "
        "at your best.pt."
    )

uploaded_file = st.file_uploader("Upload a frame photo", type=["jpg", "jpeg", "png", "bmp"])

if uploaded_file is not None:
    pil_img = Image.open(io.BytesIO(uploaded_file.getvalue()))
    model = load_yolo_model()
    img_np = np.array(pil_img.convert("RGB"))
    H, W = img_np.shape[:2]

    detections = []
    max_confidences = {}

    # Always tile — small photos get a smaller adaptive tile size (forcing
    # at least a 2x2 grid) instead of skipping tiling altogether. This is
    # what fixes small/moderate close-ups that were previously running as a
    # single un-tiled pass and producing oversized, low-confidence boxes.
    adaptive_tile_size = compute_adaptive_tile_size(H, W)

    with st.spinner(f"Running tiled detection ({W}x{H}, tile size {adaptive_tile_size}px)..."):
        raw_tiled = tiled_detection(model, img_np, tile_size=adaptive_tile_size)
        merged = merge_duplicate_detections(raw_tiled)
        merged = apply_class_rules(merged, model.names)

    with st.expander("🔍 Debug: raw tiled model output", expanded=False):
        st.write(f"**Before any filtering** — {len(raw_tiled)} raw box(es) across all tiles:")
        if not raw_tiled:
            st.write("Zero boxes returned across all tiles, before any filtering at all.")
        else:
            for x1, y1, x2, y2, conf, cls_id in sorted(raw_tiled, key=lambda d: d[4], reverse=True):
                st.write(f"  • {model.names[cls_id]}: {conf:.3f}")
        st.write(f"**After duplicate removal + class rules** — {len(merged)} box(es) kept:")
        if not merged:
            st.write("Nothing survived filtering.")
        else:
            for x1, y1, x2, y2, conf, cls_id in merged:
                st.write(f"  • {model.names[cls_id]}: {conf:.3f}")

    for x1, y1, x2, y2, conf, cls_id in merged:
        cls_name = model.names[int(cls_id)]
        x_center = ((x1 + x2) / 2) / W
        y_center = ((y1 + y2) / 2) / H
        bw = (x2 - x1) / W
        bh = (y2 - y1) / H
        detections.append((cls_id, x_center, y_center, bw, bh, conf))
        max_confidences[cls_name] = max(max_confidences.get(cls_name, 0.0), conf)

    num_tiles_used = max(1, round(H / adaptive_tile_size) * round(W / adaptive_tile_size))
    st.caption(f"ℹ️ Processed with adaptive {adaptive_tile_size}px tiles ({len(raw_tiled)} raw detections "
               f"merged down to {len(merged)}) — every photo is tiled now, not just large ones, so "
               f"individual cells get the same 'zoomed in' treatment regardless of the original photo size.")

    st.subheader("Detected Image")
    st.image(draw_boxes(pil_img, detections, model.names), use_container_width=True)

    st.subheader("Detection Confidence")
    sorted_confidences = sorted(max_confidences.items(), key=lambda x: x[1], reverse=True)
    if sorted_confidences:
        for cls_name, conf in sorted_confidences:
            if conf >= CONFIDENCE_THRESHOLD:
                st.write(f"**{DISPLAY_NAMES.get(cls_name, cls_name)}** : {conf:.2f}")
    else:
        st.write("No detections above threshold.")

    detected_classes = [cls for cls, conf in sorted_confidences if conf >= CONFIDENCE_THRESHOLD]

    # ---------------- Larvae confusion safeguard ----------------
    confusion_flags = [
        cls for cls, conf in sorted_confidences
        if cls in LARVAE_CONFUSION_RISK
        and CONFIDENCE_THRESHOLD <= conf < LARVAE_CONFUSION_CONF_CEILING
    ]
    if confusion_flags:
        st.warning(
            "⚠️ **Possible mislabeling:** " +
            ", ".join(DISPLAY_NAMES.get(c, c) for c in confusion_flags) +
            f" detected with confidence below {LARVAE_CONFUSION_CONF_CEILING:.0%} — "
            "this model version sometimes confuses these with **Larvae**. "
            "Please visually verify these specific boxes before relying on this result."
        )
    # --------------------------------------------------------------------

    observation_map = {
        "Capped_brood": "Capped worker brood detected.",
        "Drone_bee_Capped_brood": "Drone brood detected.",
        "Healthy_brood_pattern": "Healthy brood pattern detected.",
        "Eggs": "Eggs detected.",
        "Larvae": "Developing worker larvae detected.",
        "Queen_Bee": "Queen bee detected.",
    }

    real_detections = [cls for cls in detected_classes if cls in observation_map]

    if len(real_detections) >= 3:
        status_badge = "🟢 Multiple important hive resources were detected."
        status_color = "#0D47A1"
    elif len(real_detections) >= 1:
        status_badge = "🟡 Limited hive resources detected."
        status_color = "#E65100"
    elif len(detected_classes) > 0 and not USING_CUSTOM_MODEL:
        status_badge = "🔵 Generic objects detected (Custom model not loaded)."
        status_color = "#1565C0"
    else:
        status_badge = "🔴 No hive resources detected."
        status_color = "#B71C1C"

    st.subheader("Hive Inspection Summary")
    st.markdown(f"""
    <div style="background-color:{status_color}; padding:12px; border-radius:6px; color:white; margin-bottom: 15px;">
        <b>Inspection Status</b><br>
        {status_badge}
    </div>
    """, unsafe_allow_html=True)

    # ---------------- Overall Good Hive / Poor Hive verdict ----------------
    st.subheader("🐝 Overall Hive Health Verdict")
    verdict, verdict_color, verdict_emoji, health_score, max_score, reasons = assess_hive_health(
        detected_classes, USING_CUSTOM_MODEL
    )

    st.markdown(f"""
    <div style="background-color:{verdict_color}; padding:14px; border-radius:6px; color:white; margin-bottom: 10px;">
        <div style="font-size:1.1em; font-weight:700;">{verdict_emoji} {verdict}</div>
        <div style="font-size:0.9em; opacity:0.9;">Health score: {health_score} / {max_score}</div>
    </div>
    """, unsafe_allow_html=True)

    st.progress(min(health_score / max_score, 1.0) if max_score else 0)

    with st.expander("Why this verdict?", expanded=True):
        for reason in reasons:
            st.write(f"• {reason}")
        if USING_CUSTOM_MODEL:
            st.caption(
                "Note: this verdict is derived only from what's visible in this single frame. "
                "A full hive assessment normally spans multiple frames/frames over time and a "
                "physical inspection."
            )
    # -------------------------------------------------------------------------

    # ---------------- Observations ----------------
    st.subheader("Observations")
    if USING_CUSTOM_MODEL:
        for cls_name, display_obs in observation_map.items():
            if cls_name in detected_classes:
                st.write(f"✅ {display_obs}")
            else:
                absent_label = DISPLAY_NAMES.get(cls_name, cls_name)
                st.write(f"❌ {absent_label} — not detected.")
    else:
        st.write(f"ℹ️ Since custom model is missing, the generic model detected: {', '.join(detected_classes) if detected_classes else 'nothing'}")
    # ---------------------------------------------------------------------------------------

    st.subheader("Detected Classes")
    if detected_classes:
        for cls_name in YOLO_CLASSES:
            if cls_name in detected_classes:
                st.markdown(f"""
                <div style="background-color:#1B5E20; color:white; padding:10px 15px; border-radius:6px; margin-bottom:6px; font-weight:600;">
                    {DISPLAY_NAMES.get(cls_name, cls_name)}
                </div>
                """, unsafe_allow_html=True)
    else:
        st.write("No classes detected above threshold.")