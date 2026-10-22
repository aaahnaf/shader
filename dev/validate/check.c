#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define GL_GLEXT_PROTOTYPES 1
#include <GL/glx.h>
#include <GL/gl.h>
#include <GL/glext.h>

static char* readfile(const char* p, long* len) {
    FILE* f = fopen(p, "rb"); if (!f) return NULL;
    fseek(f, 0, SEEK_END); *len = ftell(f); fseek(f, 0, SEEK_SET);
    char* b = malloc(*len + 1); fread(b, 1, *len, f); b[*len] = 0; fclose(f);
    return b;
}

int main(int argc, char** argv) {
    Display* dpy = XOpenDisplay(NULL);
    if (!dpy) { fprintf(stderr, "NO X DISPLAY\n"); return 2; }
    int fbAttribs[] = { GLX_RENDER_TYPE, GLX_RGBA_BIT, GLX_DRAWABLE_TYPE, GLX_PIXMAP_BIT, None };
    int nfb = 0; GLXFBConfig* fbc = glXChooseFBConfig(dpy, DefaultScreen(dpy), fbAttribs, &nfb);
    if (!fbc) { fprintf(stderr, "NO FBCONFIG\n"); return 2; }
    int pixAttribs[] = { GLX_WIDTH, 16, GLX_HEIGHT, 16, None };
    Pixmap pm = XCreatePixmap(dpy, RootWindow(dpy, DefaultScreen(dpy)), 16, 16, 32);
    GLXContext ctx = glXCreateNewContext(dpy, fbc[0], GLX_RGBA_TYPE, None, True);
    GLXPixmap glxpm = glXCreatePixmap(dpy, fbc[0], pm, NULL);
    if (!glXMakeContextCurrent(dpy, glxpm, glxpm, ctx)) { fprintf(stderr, "CTX FAIL\n"); return 2; }
    printf("GL_RENDERER=%s | GL_VERSION=%s\n", glGetString(GL_RENDERER), glGetString(GL_VERSION));
    int ok = 1;
    for (int i = 1; i < argc; i++) {
        long len; char* src = readfile(argv[i], &len);
        if (!src) { printf("MISSING %s\n", argv[i]); ok = 0; continue; }
        const char* ext = strrchr(argv[i], '.');
        GLenum type = (ext && strcmp(ext, ".vsh")==0) ? GL_VERTEX_SHADER : GL_FRAGMENT_SHADER;
        GLuint sh = glCreateShader(type);
        glShaderSource(sh, 1, (const GLchar**)&src, &len);
        glCompileShader(sh);
        GLint status = 0; glGetShaderiv(sh, GL_COMPILE_STATUS, &status);
        char log[8192]; GLsizei llen = 0;
        glGetShaderInfoLog(sh, sizeof(log), &llen, log);
        if (status) {
            printf("OK   %s\n", argv[i]);
            if (llen > 1) printf("     (warn) %.*s\n", (int)llen, log);
        } else {
            printf("FAIL %s\n%s\n", argv[i], log); ok = 0;
        }
        glDeleteShader(sh); free(src);
    }
    return ok ? 0 : 1;
}
