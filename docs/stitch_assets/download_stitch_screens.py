import os
import json
import urllib.request

output_json_path = r"C:\Users\harsh\.gemini\antigravity-ide\brain\a784ecb9-b392-4b60-9d44-af560f027ed1\.system_generated\steps\42\output.txt"
dest_dir = r"d:\flutter projects\survey_booking_app\docs\stitch_assets"

os.makedirs(os.path.join(dest_dir, "images"), exist_ok=True)
os.makedirs(os.path.join(dest_dir, "html"), exist_ok=True)

with open(output_json_path, "r", encoding="utf-8") as f:
    data = json.load(f)

screens = data.get("screens", [])

catalog_lines = [
    "# Stitch Design System & Screen Catalog\n",
    "**Project Title:** Remix of Survey Appointment Booking System  ",
    "**Project ID:** 1110647345807758228  ",
    f"**Total Screens Downloaded:** {len(screens)}\n",
    "| # | Screen ID | Title | Device | Screenshot File | HTML Code File |",
    "|---|---|---|---|---|---|"
]

headers = {'User-Agent': 'Mozilla/5.0'}

for idx, s in enumerate(screens, 1):
    screen_id = s.get("name", "").split("/")[-1]
    title = s.get("title", f"Screen_{screen_id}")
    device = s.get("deviceType", "MOBILE")
    
    # Clean title for filename
    safe_title = "".join([c if c.isalnum() or c in (' ', '_', '-') else '' for c in title]).strip().replace(' ', '_')
    
    img_filename = f"{idx:02d}_{screen_id}_{safe_title}.png"
    html_filename = f"{idx:02d}_{screen_id}_{safe_title}.html"
    
    img_path = os.path.join(dest_dir, "images", img_filename)
    html_path = os.path.join(dest_dir, "html", html_filename)
    
    img_url = s.get("screenshot", {}).get("downloadUrl", "")
    html_url = s.get("htmlCode", {}).get("downloadUrl", "")
    
    print(f"[{idx}/{len(screens)}] Downloading {title} ({screen_id})...")
    
    if img_url:
        try:
            req = urllib.request.Request(img_url, headers=headers)
            with urllib.request.urlopen(req) as resp, open(img_path, 'wb') as out_f:
                out_f.write(resp.read())
        except Exception as e:
            print(f"  Error downloading image: {e}")
            
    if html_url:
        try:
            req = urllib.request.Request(html_url, headers=headers)
            with urllib.request.urlopen(req) as resp, open(html_path, 'wb') as out_f:
                out_f.write(resp.read())
        except Exception as e:
            print(f"  Error downloading HTML: {e}")
            
    catalog_lines.append(f"| {idx} | `{screen_id}` | {title} | {device} | [Image](file:///{img_path.replace('\\', '/')}) | [HTML](file:///{html_path.replace('\\', '/')}) |")

catalog_path = os.path.join(dest_dir, "STITCH_DESIGN_CATALOG.md")
with open(catalog_path, "w", encoding="utf-8") as f:
    f.write("\n".join(catalog_lines))

print(f"\nDone! Catalog written to {catalog_path}")
