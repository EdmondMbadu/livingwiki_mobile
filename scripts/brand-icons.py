"""Package the existing LivingWiki compass into launcher assets; no new artwork."""
import json
import subprocess
from pathlib import Path
source=Path('assets/brand/compass.png').resolve()

def resize(target,size):
    target.parent.mkdir(parents=True,exist_ok=True)
    subprocess.run(['sips','-z',str(size),str(size),str(source),'--out',str(target)],check=True,stdout=subprocess.DEVNULL)

for folder in [Path('ios/Runner/Assets.xcassets/AppIcon.appiconset'),Path('macos/Runner/Assets.xcassets/AppIcon.appiconset')]:
    data=json.loads((folder/'Contents.json').read_text())
    for entry in data['images']:
        if 'filename' in entry:
            size=round(float(entry['size'].split('x')[0])*float(entry.get('scale','1x').removesuffix('x')))
            resize(folder/entry['filename'],size)
for density,size in {'mdpi':48,'hdpi':72,'xhdpi':96,'xxhdpi':144,'xxxhdpi':192}.items():
    resize(Path(f'android/app/src/main/res/mipmap-{density}/ic_launcher.png'),size)
for name,size in {'Icon-192.png':192,'Icon-512.png':512,'Icon-maskable-192.png':192,'Icon-maskable-512.png':512}.items():
    resize(Path('web/icons')/name,size)
resize(Path('web/favicon.png'),64)
# iOS launch image retains the existing branded mark on paper.
for scale in [1,2,3]:
    resize(Path(f'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{"" if scale==1 else "@"+str(scale)+"x"}.png'),96*scale)
