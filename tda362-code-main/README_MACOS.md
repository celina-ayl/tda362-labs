# macOS with Homebrew Mesa

The standard Mac setup supports **Apple Silicon** running a recent macOS version
supported by Homebrew (macOS 15 or later). Intel Macs need individual setup and are not routinely
tested.

Mesa's llvmpipe renderer runs desktop OpenGL on the CPU, so students use the
same rendering API, shaders, and exercises as on Windows/Linux. SDL handles the
window and input. Metal only presents the image already rendered by the CPU.
Software rendering will be slower on complex scenes.

## Setup and run

Download and extract the whole course repository, then double-click
**setup-macos.command**. Keep the files together in a writable folder on your Mac.

Setup installs missing tools and VS Code, installs the C/C++ and CMake Tools
extensions, builds the labs, and opens the course folder in VS Code. Follow the
installer prompts. The first run can download several GB and take several
minutes. Homebrew installation may ask for your Mac password (typing
it in Terminal does not display characters). If Apple's Command Line Tools are
missing, setup opens their installer and waits. Finish the installation, then
press **Return** in the setup Terminal window to continue. If you press Return
too early, setup checks the tools and keeps waiting. Type `q` to stop and resume
later by running setup again.

In VS Code, trust the course folder if asked. Open **Run and Debug**, select
**lab1-rasterization**, and press **F5**.

If macOS blocks the downloaded launcher or its executable permission was lost,
open Terminal, type `bash ` (including the space), drag **setup-macos.sh** from
Finder into Terminal, and press Return. This runs the same setup.

Existing tools are reused, and setup can be rerun after an interruption. Errors
are saved in `build/setup-macos.log`; send that file to a lab assistant if you
need help. If the build cache belongs to another folder, generator, or CPU
architecture, setup preserves it in `build.previous.*` and creates a fresh build.
If VS Code was already open, close all its windows and reopen the course folder
to pick up the newly installed tools.

To check prerequisites without installing tools or changing project files, run
from the repository root:

```sh
bash setup-macos.sh --check-only
```

Use `bash setup-macos.sh --no-launch` to run setup without opening VS Code.

Setup installs CMake, SDL2, GLM, Mesa, Embree, and OpenMP through Homebrew.
Homebrew installs precompiled packages when available, including Mesa and its
LLVM dependency. Setup downloads checksum-verified GLEW 2.2.0 source and compiles
that small OpenGL loader for EGL alongside the labs. It does not compile Mesa,
require XQuartz, or replace Apple's system OpenGL.

All six labs, the project, and the pathtracer are built in `build/`. Run them
with that directory as the working directory:

```sh
cd build
./lab1-rasterization/lab1-rasterization
# Or:
./lab2-textures/lab2-textures
./project/project
./pathtracer/pathtracer
```

Startup output should identify **Mesa**, **llvmpipe**, and **OpenGL 4.5 or later**.
Close the window or press Escape to exit. Resizing adjusts the software
framebuffer, which renders at window-coordinate resolution rather than Retina
pixel resolution. Lab 2 and the project open with their GUI hidden; press **G**
to toggle it.

## VS Code and debugging

Install the recommended **C/C++** extension (`ms-vscode.cpptools`). Choose the
lab name, **project**, or **pathtracer** in Run and Debug and press F5. These
configurations build in `build/` and use LLDB on macOS. No separate Mesa launch
configuration or CodeLLDB extension is needed.

Lab 1 deliberately starts with an invalid `glClear` call. Mesa reports the error
in the terminal. With a debugger attached, the normal lab callback raises a
breakpoint signal while the offending call is still on the stack, preserving
the first debugging exercise. Running without a debugger prints the error and
continues.

## Rebuild

After setup, use the usual CMake workflow:

```sh
cd build
cmake ..
cmake --build . --parallel 4
```

Mesa is selected automatically on macOS. If you used the earlier setup that
compiled Mesa under `build/mesa-deps/` and built labs in `build/macos-mesa/`,
rerun setup to switch to the Homebrew package and the shared
`build/` directory. The old builds are no longer used.

The pathtracer uses Homebrew's native **Embree 4** and **libomp** packages. Its
lighting computation runs on the CPU with Embree and OpenMP; Mesa displays the
accumulated image. A sample limit of zero traces indefinitely.

## Implementation

`LABHELPER_USE_MESA=ON` selects the backend. It creates an OpenGL 4.5
compatibility context through Mesa's surfaceless EGL interface, renders into
an offscreen framebuffer, and reads the result into an SDL surface for display.
GLEW resolves entry points through EGL, keeping the labs' calls on Mesa.
`labhelper::swapWindow` presents the software image on Mac and swaps native
OpenGL buffers in the Windows/Linux build.

CMake finds Homebrew Mesa automatically. Nonstandard installations can set
`MESA_ROOT` and `GLEW_MESA_ROOT`. The earlier `LABHELPER_USE_OSMESA`, `OSMESA_ROOT`,
and `GLEW_OSMESA_ROOT` settings are no longer used.
