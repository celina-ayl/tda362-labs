#include "labhelper.h"
#include "mesa_window.h"
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <algorithm>
#include <vector>

namespace labhelper
{
namespace
{
EGLDisplay display = EGL_NO_DISPLAY;
EGLContext context = EGL_NO_CONTEXT;
EGLSurface framebuffer = EGL_NO_SURFACE;
EGLConfig config;
std::vector<unsigned char> pixels;
SDL_Surface* image = nullptr;
int bufferWidth = 0;
int bufferHeight = 0;

void checkEGL(EGLBoolean success, const char* operation)
{
    if(!success)
        fatal_error(std::string(operation) + " failed (EGL error " + std::to_string(eglGetError()) + ").");
}
}

void prepareMesaFrame(SDL_Window* window)
{
    int width, height;
    SDL_GetWindowSize(window, &width, &height);
    width = std::max(width, 1);
    height = std::max(height, 1);
    if(width == bufferWidth && height == bufferHeight)
        return;

    const EGLint attributes[] = {EGL_WIDTH, width, EGL_HEIGHT, height, EGL_NONE};
    EGLSurface next = eglCreatePbufferSurface(display, config, attributes);
    if(next == EGL_NO_SURFACE)
        fatal_error("Mesa could not allocate the software framebuffer.");
    checkEGL(eglMakeCurrent(display, next, next, context), "eglMakeCurrent");
    if(framebuffer != EGL_NO_SURFACE)
        eglDestroySurface(display, framebuffer);
    framebuffer = next;
    SDL_FreeSurface(image);
    pixels.resize(size_t(width) * size_t(height) * 4);
    image = SDL_CreateRGBSurfaceWithFormatFrom(pixels.data(), width, height, 32, width * 4,
                                               SDL_PIXELFORMAT_RGBA32);
    if(!image)
        fatal_error(SDL_GetError());
    SDL_SetSurfaceBlendMode(image, SDL_BLENDMODE_NONE);
    bufferWidth = width;
    bufferHeight = height;
}

SDL_Window* initMesaWindow(const char* caption, int width, int height)
{
    // Use Homebrew's software renderer regardless of the machine's GPU.
    SDL_setenv("GALLIUM_DRIVER", "llvmpipe", 1);
    SDL_setenv("LIBGL_ALWAYS_SOFTWARE", "true", 1);
#ifdef __APPLE__
    // Metal only presents the image already rendered on the CPU.
    SDL_SetHint(SDL_HINT_FRAMEBUFFER_ACCELERATION, "metal");
#endif
    SDL_Window* window = SDL_CreateWindow(caption, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                                           width, height, SDL_WINDOW_RESIZABLE);
    if(!window)
        return nullptr;
    // A surfaceless EGL display needs neither XQuartz nor Apple's OpenGL framework.
    display = eglGetPlatformDisplay(EGL_PLATFORM_SURFACELESS_MESA, nullptr, nullptr);
    if(display == EGL_NO_DISPLAY)
        fatal_error("Mesa could not create a surfaceless EGL display.");
    checkEGL(eglInitialize(display, nullptr, nullptr), "eglInitialize");
    checkEGL(eglBindAPI(EGL_OPENGL_API), "eglBindAPI");
    const EGLint configAttributes[] = {
        EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, 24, EGL_STENCIL_SIZE, 8, EGL_NONE
    };
    EGLint count = 0;
    checkEGL(eglChooseConfig(display, configAttributes, &config, 1, &count), "eglChooseConfig");
    if(!count)
        fatal_error("Mesa could not find an RGBA framebuffer with depth and stencil.");
    const EGLint contextAttributes[] = {
        EGL_CONTEXT_MAJOR_VERSION, 4, EGL_CONTEXT_MINOR_VERSION, 5,
        EGL_CONTEXT_OPENGL_PROFILE_MASK, EGL_CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT,
        EGL_CONTEXT_OPENGL_DEBUG, EGL_TRUE, EGL_NONE
    };
    context = eglCreateContext(display, config, EGL_NO_CONTEXT, contextAttributes);
    if(context == EGL_NO_CONTEXT)
        fatal_error("Mesa could not create an OpenGL 4.5 software context.");
    prepareMesaFrame(window);
    return window;
}

void presentMesaWindow(SDL_Window* window)
{
    // Read the window framebuffer without changing the lab's framebuffer or pixel-pack state.
    GLint readFramebuffer, packBuffer, alignment, rowLength, skipRows, skipPixels;
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &readFramebuffer);
    glGetIntegerv(GL_PIXEL_PACK_BUFFER_BINDING, &packBuffer);
    glGetIntegerv(GL_PACK_ALIGNMENT, &alignment);
    glGetIntegerv(GL_PACK_ROW_LENGTH, &rowLength);
    glGetIntegerv(GL_PACK_SKIP_ROWS, &skipRows);
    glGetIntegerv(GL_PACK_SKIP_PIXELS, &skipPixels);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
    GLint readBuffer;
    glGetIntegerv(GL_READ_BUFFER, &readBuffer);
    glReadBuffer(GL_BACK);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    glPixelStorei(GL_PACK_ROW_LENGTH, 0);
    glPixelStorei(GL_PACK_SKIP_ROWS, 0);
    glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
    glReadPixels(0, 0, bufferWidth, bufferHeight, GL_RGBA, GL_UNSIGNED_BYTE, pixels.data());
    glPixelStorei(GL_PACK_ALIGNMENT, alignment);
    glPixelStorei(GL_PACK_ROW_LENGTH, rowLength);
    glPixelStorei(GL_PACK_SKIP_ROWS, skipRows);
    glPixelStorei(GL_PACK_SKIP_PIXELS, skipPixels);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, packBuffer);
    glReadBuffer(readBuffer);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, readFramebuffer);
    // OpenGL starts at the bottom left; SDL surfaces start at the top left.
    const size_t stride = size_t(bufferWidth) * 4;
    for(int y = 0; y < bufferHeight / 2; ++y)
        std::swap_ranges(pixels.begin() + y * stride, pixels.begin() + (y + 1) * stride,
                         pixels.begin() + (bufferHeight - 1 - y) * stride);
    SDL_Surface* surface = SDL_GetWindowSurface(window);
    if(!surface || SDL_BlitScaled(image, nullptr, surface, nullptr) != 0 ||
       SDL_UpdateWindowSurface(window) != 0)
        fatal_error(SDL_GetError());
}

void shutdownMesaWindow()
{
    SDL_FreeSurface(image);
    image = nullptr;
    if(display != EGL_NO_DISPLAY)
    {
        eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        if(framebuffer != EGL_NO_SURFACE)
            eglDestroySurface(display, framebuffer);
        if(context != EGL_NO_CONTEXT)
            eglDestroyContext(display, context);
        eglTerminate(display);
    }
    display = EGL_NO_DISPLAY;
    context = EGL_NO_CONTEXT;
    framebuffer = EGL_NO_SURFACE;
    pixels.clear();
    bufferWidth = bufferHeight = 0;
}
}
