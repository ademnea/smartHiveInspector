import cv2
import os
from tqdm import tqdm

folder = r"D:\BeeGuard_Videos\Frames"
output = r"D:\BeeGuard_Videos\Clean_Frames"

os.makedirs(output, exist_ok=True)

threshold = 0.95

images = sorted(os.listdir(folder))

previous = None
kept = 0
removed = 0

for image_name in tqdm(images):

    path = os.path.join(folder, image_name)

    img = cv2.imread(path)

    if img is None:
        continue

    # make image smaller to save RAM
    img = cv2.resize(img, (100, 100))

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    if previous is not None:

        diff = cv2.compareHist(
            cv2.calcHist([previous], [0], None, [64], [0,256]),
            cv2.calcHist([gray], [0], None, [64], [0,256]),
            cv2.HISTCMP_CORREL
        )

        if diff > threshold:
            removed += 1
            continue

    # copy original image
    cv2.imwrite(os.path.join(output, image_name), cv2.imread(path))

    previous = gray
    kept += 1


print("\nFinished!")
print("Kept:", kept)
print("Removed:", removed)