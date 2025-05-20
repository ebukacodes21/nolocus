import os
import cv2
import exifread
import torch
import torchvision.transforms as T
from midas.dpt_depth import DPTDepthModel
from midas.transforms import Resize, NormalizeImage, PrepareForNet
from pathlib import Path

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

def estimate_depth(image_path):
    model_type = "DPT_Large"
    model = torch.hub.load("intel-isl/MiDaS", model_type).to(DEVICE).eval()
    transform = torch.hub.load("intel-isl/MiDaS", "transforms").dpt_transform

    img = cv2.imread(image_path)
    img_input = transform(img).to(DEVICE)
    with torch.no_grad():
        prediction = model(img_input)
        prediction = torch.nn.functional.interpolate(
            prediction.unsqueeze(1),
            size=img.shape[:2],
            mode="bicubic",
            align_corners=False,
        ).squeeze()
    depth_map = prediction.cpu().numpy()
    cv2.imwrite(image_path.replace(".jpg", "_depth.png"), depth_map * 255)

def extract_gps(img_path):
    with open(img_path, 'rb') as f:
        tags = exifread.process_file(f)
    gps_lat = tags.get('GPS GPSLatitude')
    gps_lon = tags.get('GPS GPSLongitude')
    return gps_lat, gps_lon

if __name__ == "__main__":
    for file in Path("/data/uploads").glob("*.jpg"):
        print(f"🔍 Processing {file}")
        estimate_depth(str(file))
        lat, lon = extract_gps(str(file))
        if lat and lon:
            print(f"📍 GPS: {lat}, {lon}")
        else:
            print("⚠️ No GPS metadata")
