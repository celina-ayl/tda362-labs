#pragma once
#include <SDL.h>

namespace labhelper
{
SDL_Window* initMesaWindow(const char* caption, int width, int height);
void prepareMesaFrame(SDL_Window* window);
void presentMesaWindow(SDL_Window* window);
void shutdownMesaWindow();
}
