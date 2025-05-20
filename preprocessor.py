import os
import cv2
import exifread
import torch
import numpy as np
from pathlib import Path

# Import MiDaS model and transforms locally
import sys
sys.path.append("/opt/MiDaS")  # path where MiDaS was cloned in Docker

from midas.dpt_depth import DPTDepthModel
from midas.transforms import Resize, NormalizeImage, PrepareForNet

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

def load_model():
    model_path = "/opt/MiDaS/weights/dpt_large-midas-2f21e586.pt"  # manually downloaded weight
    model = DPTDepthModel(
        path=model_path,
        backbone="vitl16_384",
        non_negative=True,
    )
    model.eval()
    model.to(DEVICE)
    return model

def transform_input(img):
    transform = T.Compose([
        Resize(
            width=384,
            height=384,
            resize_target=None,
            keep_aspect_ratio=True,
            ensure_multiple_of=32,
            resize_method="minimal",
            image_interpolation_method=cv2.INTER_CUBIC,
        ),
        NormalizeImage(mean=[0.5, 0.5, 0.5], std=[0.5, 0.5, 0.5]),
        PrepareForNet(),
    ])
    return transform({"image": img})["image"]

def estimate_depth(image_path, model):
    img = cv2.imread(image_path)
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    input_tensor = transform_input(img_rgb)
    input_tensor = torch.from_numpy(input_tensor).unsqueeze(0).to(DEVICE)

    with torch.no_grad():
        prediction = model(input_tensor)
        prediction = torch.nn.functional.interpolate(
            prediction.unsqueeze(1),
            size=img.shape[:2],
            mode="bicubic",
            align_corners=False,
        ).squeeze()

    depth_map = prediction.cpu().numpy()
    norm = cv2.normalize(depth_map, None, 0, 255, cv2.NORM_MINMAX)
    cv2.imwrite(image_path.replace(".jpg", "_depth.png"), norm.astype(np.uint8))

def extract_gps(img_path):
    with open(img_path, 'rb') as f:
        tags = exifread.process_file(f)
    gps_lat = tags.get('GPS GPSLatitude')
    gps_lon = tags.get('GPS GPSLongitude')
    return gps_lat, gps_lon

if __name__ == "__main__":
    model = load_model()
    for file in Path("/data/uploads").glob("*.jpg"):
        print(f"🔍 Processing {file}")
        estimate_depth(str(file), model)
        lat, lon = extract_gps(str(file))
        if lat and lon:
            print(f"📍 GPS: {lat}, {lon}")
        else:
            print("⚠️ No GPS metadata")