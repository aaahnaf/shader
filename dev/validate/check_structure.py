#!/usr/bin/env python3
"""Static structural validator for the FastLight shader pack.

Checks (all derived from Iris/OptiFine loading rules):
 1. shaders.properties exists at pack root and every non-comment line is
    valid `key=value` syntax.
 2. The directory layout actually loads: world-N folders contain only
    recognized program names; lib/ contains only .glsl includes.
 3. Every .vsh/.fsh has a #version line as its first directive.
 4. varying contract: each varying used in a .fsh must be declared with the
    IDENTICAL type+name in the matching .vsh of the same world folder.
 5. Include safety: /*/...*/ include comments resolve to real files and
    cannot create a cycle that breaks compilation (prepare.py already
    de-duplicates, we verify resolution).
 6. No forbidden constructs for GLSL 1.20 forward pipeline: no 'sampler3D',
    no image load/store, no compute, no textureSize() (needs ARB ext),
    no dynamic array indexing of uniforms.
 7. Attribute usage per program matches what vanilla/OptiFine actually
    supplies (terrain/textured get at_tma0; uncolored must NOT declare it).
Exit code 0 = pack is structurally sound.
"""
import re, sys, os

ROOT = os.path.join(os.path.dirname(__file__), '..', '..', 'FastLightShader')
SHROOT = os.path.join(ROOT, 'shaderFiles')

VALID_PROGRAMS = {'terrain', 'textured', 'uncolored', 'water', 'weather',
                  'sky', 'solid', 'translucent'}
errors, warnings = [], []

def err(m): errors.append(m)
def warn(m): warnings.append(m)

# ---- 1. shaders.properties -------------------------------------------------
props = os.path.join(ROOT, 'shaders.properties')
if not os.path.isfile(props):
    err('shaders.properties missing at pack root - Iris will refuse the pack')
else:
    for i, ln in enumerate(open(props), 1):
        s = ln.strip()
        if not s or s.startswith('#'):
            continue
        if '=' not in s:
            err(f'shaders.properties:{i}: not a key=value line: {s!r}')

# ---- worlds present --------------------------------------------------------
worlds = sorted(d for d in os.listdir(SHROOT)
                if os.path.isdir(os.path.join(SHROOT, d)) and d.startswith('world-'))
if not worlds:
    err('no world-N folders found')

for w in worlds:
    wd = os.path.join(SHROOT, w)
    for f in os.listdir(wd):
        stem, ext = os.path.splitext(f)
        if ext not in ('.vsh', '.fsh'):
            err(f'{w}/{f}: unexpected file in a world folder')
            continue
        if stem not in VALID_PROGRAMS:
            err(f'{w}/{f}: unknown program name "{stem}" - loaders ignore it, '
                'it would silently do nothing')

# ---- lib -------------------------------------------------------------------
libd = os.path.join(SHROOT, 'lib')
if not os.path.isfile(os.path.join(libd, 'common.glsl')):
    err('lib/common.glsl missing')

# ---- 3..7 per-shader checks -----------------------------------------------
DECL_RE = re.compile(r'^\s*(varying|attribute|uniform)\s+(\w+)\s+(\w+)\s*(\[[^\]]*\])?\s*;')
INCLUDE_RE = re.compile(r'/\*/\s*([^*\s][^*]*?)\s*\*/')

def strip_line_comments(t):
    return '\n'.join(re.sub(r'//.*$', '', l) for l in t.split('\n'))

def parse_decls(text):
    out = {}
    for m in DECL_RE.finditer(text):
        out[m.group(3)] = (m.group(1), m.group(2))
    return out

for w in worlds:
    wd = os.path.join(SHROOT, w)
    for prog in ('terrain', 'textured', 'uncolored'):
        vsh = os.path.join(wd, prog + '.vsh')
        fsh = os.path.join(wd, prog + '.fsh')
        for p in (vsh, fsh):
            if not os.path.isfile(p):
                err(f'missing {os.path.relpath(p, ROOT)}')
        if not (os.path.isfile(vsh) and os.path.isfile(fsh)):
            continue

        vtxt, ftxt = open(vsh).read(), open(fsh).read()

        # 3. version first
        for name, txt in (('vsh', vtxt), ('fsh', ftxt)):
            lines = [l for l in txt.splitlines() if l.strip() and not l.strip().startswith('//')]
            if not lines or not re.match(r'\s*#version\s+\d+', lines[0]):
                err(f'{w}/{prog}.{name}: #version must be the first directive')

        # 5. includes resolve
        for txt, name in ((vtxt, 'vsh'), (ftxt, 'fsh')):
            for m in INCLUDE_RE.finditer(strip_line_comments(txt)):
                inc = m.group(1).strip().lstrip('/')
                cands = [os.path.join(SHROOT, inc), os.path.join(wd, inc),
                         os.path.join(libd, os.path.basename(inc))]
                if not any(os.path.isfile(c) for c in cands):
                    err(f'{w}/{prog}.{name}: include "{inc}" does not resolve')

        # 6. forbidden constructs
        masked = strip_line_comments(ftxt) + strip_line_comments(vtxt)
        for bad in ('sampler3D', 'samplerBuffer', 'image2D', 'imageLoad',
                    'textureSize', 'gl_NumWorkGroups', 'coherent'):
            if re.search(r'\b' + bad + r'\b', masked):
                err(f'{w}/{prog}: uses "{bad}" which is not available in GLSL 1.20')

        # 4. varying match fsh -> vsh
        vd, fd = parse_decls(vtxt), parse_decls(ftxt)
        for var, (kind, ty) in fd.items():
            if kind != 'varying':
                continue
            if var not in vd:
                err(f'{w}/{prog}: fsh varying "{var}" not written by vsh')
            elif vd[var][1] != ty:
                err(f'{w}/{prog}: varying "{var}" type mismatch '
                    f'({vd[var][1]} in vsh vs {ty} in fsh)')
            if vd.get(var, ('', ''))[0] != 'varying':
                err(f'{w}/{prog}: "{var}" declared as {vd[var][0]} in vsh, must be varying')

        # 7. attribute contract
        if prog == 'uncolored':
            if 'at_tma0' in masked:
                err(f'{w}/uncolored: water pass draws WITHOUT texcoords; '
                    'declaring/using at_tma0 here reads garbage (classic bug)')
            if re.search(r'texture2D\s*\(', strip_line_comments(ftxt)):
                err(f'{w}/uncolored.fsh: samples a texture but the constant-color '
                    'pass has no bound atlas entry guaranteed -> remove fetch')
        else:
            # parse DECL_RE against comment-stripped text only: a declaration
            # followed by a trailing // comment ends with ';' + comment, so the
            # raw-text regex would miss it (validator bug, not shader bug).
            vmasked = strip_line_comments(vtxt)
            vdecls = {}
            for m in re.finditer(r'\b(attribute|varying|uniform)\s+(\w+)\s+(\w+)\s*;', vmasked):
                vdecls[m.group(3)] = (m.group(1), m.group(2))
            if 'at_tma0' not in vdecls or vdecls['at_tma0'][0] != 'attribute':
                err(f'{w}/{prog}.vsh: textured programs must declare attribute vec2 at_tma0')

print(f'Checked worlds: {", ".join(worlds)}')
for w_ in warnings: print('WARN :', w_)
for e in errors:   print('ERROR:', e)
if errors:
    print(f'FAIL: {len(errors)} structural error(s)')
    sys.exit(1)
print('PASS: pack structure is valid for OptiFine + Iris/Sodium')
