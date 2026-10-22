#!/usr/bin/env python3
"""Build the installable shaderpack zip (shaders.properties at zip root)."""
import os, zipfile
ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
SRC  = os.path.join(ROOT, 'FastLightShader')
OUT  = os.path.join(ROOT, 'FastLightShader.zip')
with zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED) as z:
    for dirpath, dirnames, filenames in os.walk(SRC):
        for fn in sorted(filenames):
            if fn == '.gitkeep': continue
            full = os.path.join(dirpath, fn)
            arc  = os.path.relpath(full, SRC)
            z.write(full, arc)
print(f'Built {os.path.relpath(OUT, ROOT)}:')
for n in zipfile.ZipFile(OUT).namelist(): print('  ', n)
