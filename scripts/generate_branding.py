#!/usr/bin/env python3
"""Regenerate committed launcher assets from the SVG (requires ImageMagick)."""
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/branding/daily_focus.svg'
RES = ROOT / 'android/app/src/main/res'
SVG = '{http://www.w3.org/2000/svg}'
source = ET.parse(SOURCE).getroot()
paths = [p.attrib['d'] for p in source.findall(f'{SVG}path')]
background = source.find(f'{SVG}rect').attrib['fill']

subprocess.run(['convert', '-background', 'none', str(SOURCE), '-resize',
                '512x512', '-strip', '-depth', '8', str(SOURCE.with_suffix('.png'))], check=True)
for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                      ('xxhdpi', 144), ('xxxhdpi', 192)]:
    subprocess.run(['convert', str(SOURCE.with_suffix('.png')), '-resize',
                    f'{size}x{size}', '-strip', '-depth', '8', str(RES / f'mipmap-{density}/ic_launcher.png')], check=True)

# The adaptive foreground remains inside Android's central safe area. Android
# supplies the launcher mask; legacy launchers use the rounded SVG raster.
foreground = '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">\n'
path_xml = ''.join(f'    <path android:fillColor="#FFFFFF" android:pathData="{p}"/>\n' for p in paths)
(RES / 'drawable/ic_launcher_foreground.xml').write_text(foreground + path_xml + '</vector>\n')
notification = '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="54" android:viewportHeight="54">\n  <group android:translateX="-27" android:translateY="-24">\n'
(RES / 'drawable/ic_stat_focus.xml').write_text(notification + path_xml + '</group>\n</vector>\n')
(RES / 'values/launcher_colors.xml').write_text(f'<resources>\n    <color name="launcher_background">{background}</color>\n</resources>\n')
