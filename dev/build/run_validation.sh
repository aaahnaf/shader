#!/bin/bash
# Offline validation sweep: resolve includes + inject loader uniforms, then
# compile every shader with a real GLSL 1.20 front-end (glslangValidator).
set -u
SHROOT=FastLightShader/shaderFiles
OUT=dev/build/prepared
rm -rf "$OUT"; mkdir -p "$OUT"
fail=0
for f in $(find "$SHROOT" -name '*.vsh' -o -name '*.fsh' | sort); do
    base=$(echo "$f" | sed "s|$SHROOT/||; s|/|_|g")
    prep="$OUT/${base}"
    if ! python3 dev/validate/prepare.py "$f" "$prep"; then
        echo "PREPARE-FAIL $f"; fail=1; continue
    fi
    # glslangValidator needs an extension to know the stage
    case "$prep" in
        *.vsh) cp "$prep" "$OUT/tmp.v.vert"; target="$OUT/tmp.v.vert";;
        *.fsh) cp "$prep" "$OUT/tmp.f.frag"; target="$OUT/tmp.f.frag";;
    esac
    msg=$(glslangValidator "$target" 2>&1)
    if [ $? -eq 0 ]; then
        echo "OK   $f"
        echo "$msg" | grep -E "warning" && true
    else
        echo "FAIL $f"; echo "$msg" | head -40; fail=1
    fi
done
exit $fail
