import os
import cv2
import exifread
import torch
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
    # Save depth map as 16-bit PNG for better precision
    depth_map_normalized = cv2.normalize(depth_map, None, 0, 65535, cv2.NORM_MINMAX).astype('uint16')
    depth_path = image_path.replace(".jpg", "_depth.png")
    cv2.imwrite(depth_path, depth_map_normalized)
    print(f"Depth map saved to {depth_path}")

def extract_gps(img_path):
    with open(img_path, 'rb') as f:
        tags = exifread.process_file(f)

    gps_lat = tags.get('GPS GPSLatitude')
    gps_lat_ref = tags.get('GPS GPSLatitudeRef')
    gps_lon = tags.get('GPS GPSLongitude')
    gps_lon_ref = tags.get('GPS GPSLongitudeRef')

    if not all([gps_lat, gps_lat_ref, gps_lon, gps_lon_ref]):
        return None, None

    def dms_to_dd(dms):
        d, m, s = [float(x.num) / float(x.den) for x in dms.values]
        return d + m / 60.0 + s / 3600.0

    lat = dms_to_dd(gps_lat)
    if gps_lat_ref.values[0] != 'N':
        lat = -lat

    lon = dms_to_dd(gps_lon)
    if gps_lon_ref.values[0] != 'E':
        lon = -lon

    return lat, lon

if __name__ == "__main__":
    img_folder = "/data/uploads"
    for img_file in Path(img_folder).glob("*.jpg"):
        print(f"🔍 Processing {img_file.name}")
        estimate_depth(str(img_file))
        lat, lon = extract_gps(str(img_file))
        if lat and lon:
            print(f"📍 GPS Coordinates: {lat:.6f}, {lon:.6f}")
        else:
            print("⚠️ No GPS metadata found")