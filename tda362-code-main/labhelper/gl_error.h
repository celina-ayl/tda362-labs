#pragma once

// GLU is unnecessary for error descriptions and would link Apple's OpenGL on macOS.
inline const char* glErrorDescription(GLenum error)
{
    switch(error)
    {
    case GL_INVALID_ENUM: return "invalid enum";
    case GL_INVALID_VALUE: return "invalid value";
    case GL_INVALID_OPERATION: return "invalid operation";
    case GL_INVALID_FRAMEBUFFER_OPERATION: return "invalid framebuffer operation";
    case GL_OUT_OF_MEMORY: return "out of memory";
    case GL_STACK_UNDERFLOW: return "stack underflow";
    case GL_STACK_OVERFLOW: return "stack overflow";
    default: return "unknown OpenGL error";
    }
}
