# BeeGuard Custom YOLO — Build Guide

Since the zero-shot auto-labeler wasn't working reliably, this skips that step
entirely and goes straight from **manual annotation → trained YOLO model →
your Streamlit app**. With a CUDA GPU, training is fast enough that this is
actually the more reliable path anyway.

## 1. Collect frame photos

Reuse the frames you already have in `D:\BeeGuard_Videos\Clean_Frames`. Aim for
at least **150-200 images per class** for a first solid model — fewer will
still train, but accuracy on the rarer classes (e.g. `UncappedWorkerLarvaCell`)
will suffer. Vary lighting, frame angle, and zoom level so the model
generalizes past your test photos.

## 2. Annotate

You don't need CVAT specifically — either of these works and both export
directly to YOLO format:

- **CVAT** (self-hosted or app.cvat.ai) — good if you're already set up with it.
- **Roboflow** (roboflow.com, free tier) — faster to get started, browser-based,
  and its "Export Dataset → YOLOv8" option gives you the exact folder layout
  this pipeline expects.

Annotate with these 6 class names (order matters — must match `data.yaml`):

```
0 BeeHiveFrame
1 CappedHoneyCell
2 CappedWorkerBroodCell
3 PollenCell
4 UncappedNectarCell
5 UncappedWorkerLarvaCell
```

Tips specific to this task:
- Draw `BeeHiveFrame` as one big box around the whole frame in every image.
- Cells are small and dense — zoom in while annotating so boxes stay tight.
  Loose/overlapping boxes are the #1 cause of poor mAP on this kind of data.
- Skip ambiguous cells rather than guessing; a slightly smaller clean dataset
  beats a noisy larger one.

## 3. Split into train/val

If your annotation tool exported one flat folder of `image.jpg` + `image.txt`
pairs:

```bash
pip install ultralytics --break-system-packages
python3 split_dataset.py --src D:/BeeGuard_Videos/annotated --dst D:/BeeGuard_Videos/yolo_dataset --val-frac 0.15
```

This produces the exact layout `data.yaml` expects:

```
D:/BeeGuard_Videos/yolo_dataset/
    images/train/*.jpg
    images/val/*.jpg
    labels/train/*.txt
    labels/val/*.txt
```

(If Roboflow/CVAT already gave you train/val splits directly, just copy them
into this layout instead and skip this step.)

## 4. Train

Update the `path:` line in `data.yaml` if your dataset lives somewhere else,
then:

```bash
python3 train.py --model yolo11s.pt --epochs 150 --imgsz 960
```

Notes:
- `imgsz=960` (vs. the YOLO default of 640) matters here — comb cells are
  small relative to the full frame, and a larger input resolution gives the
  model more pixels to work with per cell.
- `--model yolo11n.pt` trains faster if you want a quick sanity-check run
  first; switch to `yolo11s.pt` or `yolo11m.pt` for your real training run.
- Training prints per-class mAP50 at the end so you can see which classes
  need more annotated examples.
- Best weights land at `beeguard_model/train/weights/best.pt`.

## 5. Deploy in the app

Open `app.py` and confirm `CUSTOM_MODEL_PATH` points at the `best.pt` from
step 4 (it defaults to the path `train.py` produces). Then:

```bash
pip install streamlit pytorch-grad-cam --break-system-packages
streamlit run app.py
```

Upload a frame photo and you'll get the same detected-image / confidence list
/ inspection summary / observations / Grad-CAM breakdown as your original app,
now running on your real classes.

## If accuracy is disappointing at first

This is normal for a first pass. In order of impact:
1. Add more annotated images, especially for whichever class had the lowest
   mAP50 in the training printout.
2. Double-check box tightness on a sample of your annotations — loose boxes
   quietly cap accuracy no matter how much data you add.
3. Increase `--epochs` if the training loss curve (in
   `beeguard_model/train/results.png`) hadn't flattened out yet.
4. Try `yolo11m.pt` as the base model once you have >500 total annotated
   images — bigger backbones need more data to earn their keep.