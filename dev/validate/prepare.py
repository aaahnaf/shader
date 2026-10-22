#!/usr/bin/env python3
"""Prepare Iris/OptiFine shaders for offline GLSL 1.20 validation.

- Resolves /*/path*/ include directives (Iris/OptiFine style), searching the
  program's own directory, the shaderFiles root and lib/. Include comments
  appearing inside // line comments are ignored (masking pass).
- Injects ONLY the non-reserved uniforms that a source references but does not
  declare itself (frameTimeCounter, sunAngle, texture0...), plus lowercase
  gl_* aliases that Iris injects at runtime. Reserved GLSL 1.20 builtins come
  from the compiler itself, so we never redeclare them.

Usage: prepare.py <input.vsh|input.fsh> <output> """
import re, sys, os

COMMON_UNIFORMS = {
    'frameTimeCounter': 'uniform float frameTimeCounter;',
    'sunAngle': 'uniform vec3 sunAngle;',
    'moonAngle': 'uniform vec3 moonAngle;',
    'worldOutType': 'uniform int worldOutType;',
    'isEyeInWater': 'uniform int isEyeInWater;',
    'heldBlockLightValue': 'uniform int heldBlockLightValue;',
    'heldBlockLightValue2': 'uniform int heldBlockLightValue2;',
    'texture0': 'uniform sampler2D texture0;',
    'texture1': 'uniform sampler2D texture1;',
}

GL_ALIASES = [
    ('gl_projectionMatrix', '#define gl_projectionMatrix gl_ProjectionMatrix'),
    ('gl_modelViewMatrix',  '#define gl_modelViewMatrix gl_ModelViewMatrix'),
    ('gl_textureMatrix0',   '#define gl_textureMatrix0 gl_TextureMatrix[0]'),
]

def mask_line_comments(text):
    return '\n'.join(re.sub(r'//.*$', '', ln) for ln in text.split('\n'))

INCLUDE_RE = re.compile(r'/\*/\s*([^*\s][^*]*?)\s*\*/')

def resolve(path, searchdirs, seen):
    key = os.path.normcase(os.path.abspath(path))
    if key in seen:
        return ""
    seen.add(key)
    src = open(path).read()

    def repl(m):
        inc = m.group(1).strip().lstrip('/')
        for d in searchdirs:
            c = os.path.join(d, inc)
            if os.path.isfile(c):
                body = resolve(c, searchdirs, seen)
                # strip any #version lines from included files
                return "\n" + re.sub(r'^\s*#version\s+\d+\s*$', '', body, flags=re.M) + "\n"
        raise FileNotFoundError(f"include '{inc}' not found (from {path})")

    for _ in range(10):
        masked = mask_line_comments(src)
        if not INCLUDE_RE.search(masked):
            break
        src = INCLUDE_RE.sub(repl, src)
    return src

def main():
    inp, outp = sys.argv[1], sys.argv[2]
    d = os.path.dirname(os.path.abspath(inp))
    searchdirs = [d, os.path.dirname(d), os.path.join(os.path.dirname(d), 'lib')]
    src = resolve(inp, searchdirs, set())
    m = re.match(r'\s*#version\s+(\d+)\s*$', src, re.M)
    ver = m.group(1) if m else "120"
    rest = re.sub(r'^\s*#version\s+\d+\s*$', '', src, count=1, flags=re.M)
    masked = mask_line_comments(rest)
    decls = []
    for name, alias in GL_ALIASES:
        if re.search(r'\b' + name + r'\b', masked):
            decls.append(alias)
    for name, decl in COMMON_UNIFORMS.items():
        if re.search(r'\b' + name + r'\b', masked):
            if not re.search(r'uniform\s+\w+\s+' + name + r'\s*(;|\[|=)', masked):
                decls.append(decl)
    with open(outp, 'w') as f:
        f.write(f"#version {ver}\n// --- loader-injected preamble (validation simulation) ---\n"
                + "\n".join(decls) + "\n" + rest)

if __name__ == '__main__':
    main()
