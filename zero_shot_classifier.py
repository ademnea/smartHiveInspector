"""
zero_shot_classifier.py

Real deep-learning classification backend for BeeGuard, using the
Grounding DINO model you already have downloaded in model_files/
(the same model Auto_label_zero_shot.py uses). No internet needed at
inference time - it's already on disk.

Unlike ORB feature matching, this model actually understands the text
description of each class ("drone brood cell, large domed bulging capped
cell") and finds real matching regions in the photo with real, calibrated
confidence scores (0-1) - not a count of accidentally-similar corner points.

This replaces brood_classifier.py as the engine behind app.py.
"""

from pathlib import Path

import numpy as np
import torch
from PIL import Image
from transformers import AutoProcessor, AutoModelForZeroShotObjectDetection

# ------------------------------------------------------------------
# Config - same classes/phrasing as Auto_label_zero_shot.py, kept in sync
# so both tools "think" the same way. Keys use the same lowercase/underscore
# style as your templates/ folder names.
#
# "concerning_pattern" is a judgment call in wording, not a settled fact -
# meant to catch visual signs beekeepers associate with brood disease
# (AFB/EFB, chalkbrood, sacbrood, etc.) WITHOUT claiming to diagnose any of
# them. It's deliberately generic/visual (irregular pattern, sunken/
# perforated cappings, discoloration), not naming a disease, because
# Grounding DINO matches visual descriptions, not pathology. Tune this
# phrase against what you actually see in your hives.
# ------------------------------------------------------------------
CLASSES = {
    "capped_brood":          "capped brood cell. tan colored capped cell in honeycomb",
    "drone_capped_brood":    "drone brood cell. large domed bulging capped cell",
    "healthy_brood_pattern": "solid compact brood pattern. tightly packed capped cells",
    "eggs":                  "bee egg. slender white oval standing upright in the bottom of a cell, like a tiny grain of rice, not curled",
    "larvae":                "bee larva. plump white grub curled into a C shape, glistening in liquid at the bottom of a cell",
    "queen_bee":              "queen bee. long bodied bee with elongated abdomen",
    "concerning_pattern":    "irregular blotchy brood pattern. scattered empty cells, "
                             "sunken or perforated cappings, discolored greasy looking cells",
}

MODEL_ID = r"D:\BeeGuard_Videos\model_files"

# Two different thresholds, same idea as the old MIN_GOOD_MATCHES split:
#   BOX_THRESHOLD   - minimum score for a detected region to count at all
#   CONFIDENT_SCORE - minimum score for the *top* result to be treated as
#                     a trustworthy verdict, rather than "inconclusive"
BOX_THRESHOLD = 0.25
CONFIDENT_SCORE = 0.30

# Phone photos are often 3000-4000px wide - the model doesn't need that much
# detail and it's the single biggest lever on inference speed. Resizing down
# before inference (then scaling detected boxes back up for display) cuts
# run time substantially with negligible accuracy loss for this use case.
MAX_INFERENCE_DIM = 1400

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"


def load_model():
    """Loads the already-downloaded model from disk. No network call."""
    processor = AutoProcessor.from_pretrained(MODEL_ID)
    model = AutoModelForZeroShotObjectDetection.from_pretrained(MODEL_ID).to(DEVICE)
    model.eval()
    return processor, model


def build_text_prompt():
    return " . ".join(CLASSES.values()) + " ."


# Precompute how many classes each word appears in, so shared words like
# "brood", "cell", "capped" (which show up in 3+ class descriptions) count
# for less than distinctive words like "drone", "queen", "egg", "domed".
def _build_word_weights():
    word_class_count = {}
    per_class_words = {}
    for class_key, phrase in CLASSES.items():
        words = {w.strip(".") for w in phrase.lower().split() if len(w) > 3}
        per_class_words[class_key] = words
        for w in words:
            word_class_count[w] = word_class_count.get(w, 0) + 1
    return per_class_words, word_class_count


_PER_CLASS_WORDS, _WORD_CLASS_COUNT = _build_word_weights()


def match_label_to_class(detected_phrase):
    """Grounding DINO returns the matched span of text back; map it to one
    of our class keys using weighted word overlap - distinctive words
    (unique to one class) count far more than words shared across several
    class descriptions ("brood", "cell", "capped" all appear in 3+ classes)."""
    detected_words = {w.strip(".") for w in detected_phrase.lower().split() if len(w) > 3}
    if not detected_words:
        return None

    best_class, best_score = None, 0.0
    for class_key, class_words in _PER_CLASS_WORDS.items():
        score = 0.0
        for w in detected_words & class_words:
            score += 1.0 / _WORD_CLASS_COUNT[w]  # rarer word = more weight
        if score > best_score:
            best_score = score
            best_class = class_key
    return best_class


def run_detection(processor, model, pil_image, text_prompt):
    """Runs the model once on the whole image. Returns raw boxes/scores/labels."""
    inputs = processor(images=pil_image, text=text_prompt, return_tensors="pt").to(DEVICE)
    with torch.inference_mode():
        outputs = model(**inputs)

    # Newer transformers renamed box_threshold -> threshold; support both,
    # same pattern as Auto_label_zero_shot.py.
    try:
        results = processor.post_process_grounded_object_detection(
            outputs, inputs.input_ids,
            threshold=BOX_THRESHOLD, text_threshold=BOX_THRESHOLD,
            target_sizes=[pil_image.size[::-1]],
        )[0]
    except TypeError:
        results = processor.post_process_grounded_object_detection(
            outputs, inputs.input_ids,
            box_threshold=BOX_THRESHOLD, text_threshold=BOX_THRESHOLD,
            target_sizes=[pil_image.size[::-1]],
        )[0]
    return results


def classify_pil_image(pil_img, processor, model):
    """
    Runs zero-shot detection and buckets every detected region into one of
    our classes. Returns a dict with real per-class detection counts,
    each class's best confidence score, all boxes for drawing, and an
    overall top pick.
    """
    orig_w, orig_h = pil_img.size
    scale = MAX_INFERENCE_DIM / max(orig_w, orig_h)
    if scale < 1.0:
        inference_img = pil_img.resize((int(orig_w * scale), int(orig_h * scale)))
    else:
        inference_img = pil_img
        scale = 1.0

    text_prompt = build_text_prompt()
    results = run_detection(processor, model, inference_img.convert("RGB"), text_prompt)

    label_key = "text_labels" if "text_labels" in results else "labels"

    counts = {c: 0 for c in CLASSES}
    max_score = {c: 0.0 for c in CLASSES}
    boxes_by_class = {c: [] for c in CLASSES}
    all_detections = []  # (class_key, box, score) - box coords are in ORIGINAL image space

    for box, score, label in zip(results["boxes"], results["scores"], results[label_key]):
        cls = match_label_to_class(label)
        if cls is None:
            continue
        score = float(score)
        # scale detection box (in resized-image coords) back up to original image coords
        box = [float(v) / scale for v in box.tolist()]
        counts[cls] += 1
        max_score[cls] = max(max_score[cls], score)
        boxes_by_class[cls].append((box, score))
        all_detections.append((cls, box, score, label))

    ranked = sorted(max_score.items(), key=lambda kv: kv[1], reverse=True)
    top_cat, top_score = ranked[0]
    confident = top_score >= CONFIDENT_SCORE

    top_box = None
    if boxes_by_class[top_cat]:
        top_box = max(boxes_by_class[top_cat], key=lambda bs: bs[1])[0]

    return {
        "ranked": ranked,                  # [(class, best_score), ...] best first
        "counts": counts,                  # {class: number of detected regions}
        "top_cat": top_cat,
        "top_score": top_score,
        "confident": confident,
        "top_box": top_box,                # real bounding box, or None if nothing detected
        "all_detections": all_detections,  # for drawing every box, not just the winner
        "total_detections": len(all_detections),
    }


# ---------------------------------------------------------------------
# Zoom crops - full-resolution crop of one detected box, padded a bit for
# context and upscaled if small, so a single egg is actually visible
# instead of a handful of pixels.
# ---------------------------------------------------------------------
CROP_PAD_RATIO = 0.25
MIN_CROP_DISPLAY_PX = 260


def crop_region(pil_img, box, pad_ratio=CROP_PAD_RATIO, min_display_px=MIN_CROP_DISPLAY_PX):
    img = pil_img.convert("RGB")
    W, H = img.size
    x0, y0, x1, y1 = box
    bw, bh = (x1 - x0), (y1 - y0)
    pad_x, pad_y = bw * pad_ratio, bh * pad_ratio
    cx0 = max(0, int(x0 - pad_x))
    cy0 = max(0, int(y0 - pad_y))
    cx1 = min(W, int(x1 + pad_x))
    cy1 = min(H, int(y1 + pad_y))
    if cx1 <= cx0 or cy1 <= cy0:
        return None
    crop = img.crop((cx0, cy0, cx1, cy1))
    short_side = min(crop.width, crop.height)
    if 0 < short_side < min_display_px:
        factor = min_display_px / short_side
        crop = crop.resize((int(crop.width * factor), int(crop.height * factor)), Image.LANCZOS)
    return crop


# ---------------------------------------------------------------------
# Optional captioning - a general-purpose image-captioning model, kept
# fully separate and lazily loaded (only pulled in if the user turns the
# toggle on in the UI). NOT trained on beekeeping photos - a second
# opinion for your own judgment, not a beekeeping-aware description.
# ---------------------------------------------------------------------
CAPTION_MODEL_ID = "Salesforce/blip-image-captioning-base"
_CAPTION_STATE = {"processor": None, "model": None, "device": None}


def load_caption_model():
    """Loads the captioning model once (first call downloads it if not
    already cached locally by transformers). Safe to call repeatedly."""
    if _CAPTION_STATE["model"] is not None:
        return
    from transformers import BlipProcessor, BlipForConditionalGeneration

    processor = BlipProcessor.from_pretrained(CAPTION_MODEL_ID)
    model = BlipForConditionalGeneration.from_pretrained(CAPTION_MODEL_ID)
    device = "cuda" if torch.cuda.is_available() else "cpu"
    model = model.to(device)
    model.eval()
    _CAPTION_STATE["processor"] = processor
    _CAPTION_STATE["model"] = model
    _CAPTION_STATE["device"] = device


def describe_crop(pil_crop, max_new_tokens=30):
    """Plain-English caption for one cropped patch. Loads the caption
    model on first use if it hasn't been loaded yet."""
    load_caption_model()
    processor = _CAPTION_STATE["processor"]
    model = _CAPTION_STATE["model"]
    device = _CAPTION_STATE["device"]
    inputs = processor(pil_crop, return_tensors="pt").to(device)
    with torch.inference_mode():
        out = model.generate(**inputs, max_new_tokens=max_new_tokens)
    return processor.decode(out[0], skip_special_tokens=True)


# =====================================================================
# Grad-CAM explainability
# =====================================================================
# HONEST CAVEAT: Grad-CAM was designed for plain CNN classifiers, where
# "the last conv layer" is an obvious, named thing. Grounding DINO is a
# transformer detector (a Swin/ViT backbone feeding a transformer
# encoder-decoder) - there's no single official "last conv layer" to
# point at, and the exact module names differ across transformers
# versions. This implementation works AROUND that instead of assuming
# a fixed layer name:
#   1. It watches every leaf module during one forward pass and keeps
#      whichever 4D (batch, channel, height, width) feature map came out
#      LAST - that's reliably the deepest backbone feature map, right
#      before it gets flattened for the transformer encoder.
#   2. It backpropagates from the model's own class-matching logit for
#      the class you asked about (found via text-token offsets, the
#      same mechanism Grounding DINO itself uses to line up words with
#      detections) into that feature map.
#   3. Standard Grad-CAM math from there: channel-wise gradient average
#      as weights, weighted sum of activations, ReLU.
#
# This has NOT been run against your actual model_files/ (no internet or
# GPU in the environment this was written in). If it raises or returns
# None, the error message will say what went wrong - please paste it
# back and we'll adjust the hook rather than guess blind.
# ---------------------------------------------------------------------

def _register_last_4d_activation_hook(model):
    """Registers a forward hook on every leaf module; keeps a reference
    to the LAST 4D tensor output seen during the forward pass, with
    retain_grad() called on it so we can read .grad after backward()."""
    state = {"tensor": None, "name": None}
    handles = []

    def make_hook(name):
        def hook(module, inputs, output):
            t = output[0] if isinstance(output, (tuple, list)) else output
            if torch.is_tensor(t) and t.dim() == 4 and t.requires_grad:
                t.retain_grad()
                state["tensor"] = t
                state["name"] = name
        return hook

    for name, module in model.named_modules():
        if len(list(module.children())) == 0:  # leaf modules only
            handles.append(module.register_forward_hook(make_hook(name)))

    return state, handles


def _find_class_token_indices(processor, text_prompt, class_phrase):
    """Maps a class's text phrase to the indices of the text tokens that
    make it up, using the tokenizer's own character offsets - the same
    kind of alignment Grounding DINO relies on internally to match words
    to detections."""
    tokenized = processor.tokenizer(text_prompt, return_offsets_mapping=True)
    offsets = tokenized["offset_mapping"]
    start = text_prompt.index(class_phrase)
    end = start + len(class_phrase)
    indices = [
        i for i, (s, e) in enumerate(offsets)
        if not (s == 0 and e == 0) and e > start and s < end
    ]
    return indices


def compute_gradcam(pil_img, processor, model, target_class_key):
    """
    Grad-CAM heatmap showing which pixels drove the model's confidence
    for `target_class_key` (must be a key in CLASSES), computed over the
    WHOLE image (not one specific box) - i.e. "where did the model look
    to decide how much 'eggs' is in this photo," across every candidate
    region at once.

    Returns a numpy array, shape (H, W) of pil_img, values 0-255
    (uint8), or None if the heatmap couldn't be computed - in which case
    a message is printed explaining why (check your terminal / stderr).
    """
    if target_class_key not in CLASSES:
        print(f"[gradcam] unknown class key: {target_class_key}")
        return None

    orig_w, orig_h = pil_img.size
    scale = MAX_INFERENCE_DIM / max(orig_w, orig_h)
    if scale < 1.0:
        inference_img = pil_img.resize((int(orig_w * scale), int(orig_h * scale)))
    else:
        inference_img = pil_img

    text_prompt = build_text_prompt()
    class_phrase = CLASSES[target_class_key]

    try:
        token_indices = _find_class_token_indices(processor, text_prompt, class_phrase)
        if not token_indices:
            print(f"[gradcam] couldn't map '{target_class_key}' to any text tokens.")
            return None

        inputs = processor(images=inference_img.convert("RGB"), text=text_prompt,
                            return_tensors="pt").to(DEVICE)

        state, handles = _register_last_4d_activation_hook(model)
        try:
            model.zero_grad(set_to_none=True)
            with torch.set_grad_enabled(True):
                outputs = model(**inputs)

                if not hasattr(outputs, "logits"):
                    print("[gradcam] model output has no 'logits' attribute on this "
                          "transformers version - can't identify the target score.")
                    return None

                logits = outputs.logits  # expected shape: (batch, num_queries, text_len)
                if logits.dim() != 3:
                    print(f"[gradcam] unexpected logits shape {tuple(logits.shape)} - "
                          f"expected (batch, queries, text_tokens).")
                    return None

                class_logits = logits[0, :, token_indices]
                target_score = class_logits.max()

                activation = state["tensor"]
                if activation is None:
                    print("[gradcam] no 4D feature map was captured during the forward "
                          "pass - the backbone in your installed transformers version "
                          "may structure its layers differently than expected.")
                    return None

                target_score.backward()

                grads = activation.grad
                if grads is None:
                    print(f"[gradcam] gradient never reached the captured layer "
                          f"('{state['name']}') - it may sit outside the path from the "
                          f"text logits back to the image backbone.")
                    return None

                weights = grads.mean(dim=(2, 3), keepdim=True)
                cam = torch.relu((weights * activation).sum(dim=1, keepdim=True))
                cam = cam[0, 0].detach().cpu().float().numpy()
        finally:
            for h in handles:
                h.remove()

        cam_min, cam_max = cam.min(), cam.max()
        if cam_max - cam_min < 1e-8:
            print("[gradcam] heatmap was flat (no signal) - the class likely had "
                  "near-zero confidence anywhere in this photo.")
            return None
        cam = (cam - cam_min) / (cam_max - cam_min)

        cam_img = Image.fromarray((cam * 255).astype(np.uint8))
        cam_img = cam_img.resize((orig_w, orig_h), Image.BILINEAR)
        return np.array(cam_img)

    except Exception as e:
        print(f"[gradcam] failed: {e}")
        return None


def _jet_colormap(x):
    """Cheap dependency-free jet-style colormap. x: float array 0-1.
    Returns (r, g, b) arrays 0-255, same shape as x."""
    r = np.clip(np.minimum(4 * x - 1.5, -4 * x + 4.5), 0, 1)
    g = np.clip(np.minimum(4 * x - 0.5, -4 * x + 3.5), 0, 1)
    b = np.clip(np.minimum(4 * x + 0.5, -4 * x + 2.5), 0, 1)
    return (r * 255).astype(np.uint8), (g * 255).astype(np.uint8), (b * 255).astype(np.uint8)


def overlay_heatmap(pil_img, heatmap_0_255, alpha=0.45):
    """Blends a Grad-CAM heatmap (0-255 uint8, same size as pil_img) over
    the original photo using a jet-style colormap. Blend strength scales
    with heatmap intensity, so low-activation areas stay closer to the
    original photo and hot spots stand out."""
    base = np.array(pil_img.convert("RGB")).astype(np.float32)
    x = heatmap_0_255.astype(np.float32) / 255.0
    r, g, b = _jet_colormap(x)
    color = np.stack([r, g, b], axis=-1).astype(np.float32)
    a = (alpha * x)[..., None]
    blended = base * (1 - a) + color * a
    return Image.fromarray(np.clip(blended, 0, 255).astype(np.uint8))

BLUR_THRESHOLD = 150
DARKNESS_THRESHOLD = 40


def get_match_evidence(detected_phrase, class_key):
    """Returns the words that drove this detection into this class, most
    distinctive first."""
    detected_words = {w.strip(".") for w in detected_phrase.lower().split() if len(w) > 3}
    class_words = _PER_CLASS_WORDS.get(class_key, set())
    matched = detected_words & class_words
    return sorted(matched, key=lambda w: _WORD_CLASS_COUNT.get(w, 1))


def assess_image_quality(pil_img):
    """Returns (ok: bool, reason: str, fix: str)."""
    from PIL import ImageFilter
    gray = pil_img.convert("L")
    brightness = float(np.array(gray).mean())
    edges = gray.filter(ImageFilter.FIND_EDGES)
    sharpness = float(np.array(edges, dtype=np.float64).var())

    if brightness < DARKNESS_THRESHOLD:
        return False, "Too dark to analyze reliably.", "Retake in brighter light, avoid shadows."
    if sharpness < BLUR_THRESHOLD:
        return False, "Too blurry to analyze reliably.", "Hold steady, move closer, let it focus."
    return True, "Good.", ""


BLUR_THRESHOLD = 150
DARKNESS_THRESHOLD = 40


def get_match_evidence(detected_phrase, class_key):
    """Returns the words that drove this detection into this class, most
    distinctive first."""
    detected_words = {w.strip(".") for w in detected_phrase.lower().split() if len(w) > 3}
    class_words = _PER_CLASS_WORDS.get(class_key, set())
    matched = detected_words & class_words
    return sorted(matched, key=lambda w: _WORD_CLASS_COUNT.get(w, 1))


def assess_image_quality(pil_img):
    """Returns (ok: bool, reason: str, fix: str)."""
    from PIL import ImageFilter
    gray = pil_img.convert("L")
    brightness = float(np.array(gray).mean())
    edges = gray.filter(ImageFilter.FIND_EDGES)
    sharpness = float(np.array(edges, dtype=np.float64).var())

    if brightness < DARKNESS_THRESHOLD:
        return False, "Too dark to analyze reliably.", "Retake in brighter light, avoid shadows."
    if sharpness < BLUR_THRESHOLD:
        return False, "Too blurry to analyze reliably.", "Hold steady, move closer, let it focus."
    return True, "Good.", ""



