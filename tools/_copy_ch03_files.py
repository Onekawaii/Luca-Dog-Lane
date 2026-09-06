from pathlib import Path
import shutil
root = Path(__file__).resolve().parent.parent
shutil.copyfile(root / 'content' / '_tmp_ch03_rooms_v3.json', root / 'content' / 'rooms_ch03.json')
shutil.copyfile(root / 'content' / '_tmp_ch03_items_v3.json', root / 'content' / 'items.json')
shutil.copyfile(root / 'content' / '_tmp_ch03_characters_v3.json', root / 'content' / 'characters.json')
print('copied')
