# Description
This is the repository for the tutorials of the course TDA362/DIT223 Computer Graphics given at Chalmers University of
Technology. It contains resources and skeleton code which is to be filled in by students in six different lab assignments and one larger project.

The accompanying web page to this repository is located at http://www.cse.chalmers.se/edu/course/TDA362/tutorials/index.html.

Instructions on how to use this repository specifically can be found at http://www.cse.chalmers.se/edu/course/TDA362/tutorials/start.html.

## macOS

For the Mesa software-rendering backend, see [README_MACOS.md](README_MACOS.md).
On Apple Silicon Macs with macOS 15 or later, extract the whole repository and
double-click **setup-macos.command**. Follow the installer prompts; if asked to
install Apple's Command Line Tools, finish that installation and press Return
in the setup window to continue.
Setup installs the tools and VS Code extensions, builds the labs, and opens
VS Code. Select **lab1-rasterization** in **Run and Debug** and press **F5**.
Errors are saved in `build/setup-macos.log`.

## VS Code

On Windows x64, extract the whole repository and double-click
**setup-windows.cmd**. It installs missing tools and the VS Code extensions,
builds the labs, and opens the folder in VS Code.
Approve the installers when Windows asks; if a restart is requested, restart
and run setup again. Then choose **lab1-rasterization** in **Run and Debug**
and press **F5**. Setup uses Windows App Installer (`winget`) to install VS Code,
CMake, and Git, and Microsoft's installer for the C++ Build Tools. It can be
rerun and reuses existing tools. Errors are saved in `build/setup-windows.log`.
If an existing CMake cache uses another configuration, setup preserves the old
build folder as `build.previous.*` and creates a fresh x64 build automatically.
You do not need to run setup on a lab computer that is already configured.

To check installed prerequisites without changing anything:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-windows.ps1 -CheckOnly
```

For manual setup, follow the instructions below.

Open this repository folder in VS Code and install the recommended **C/C++**
and **CMake Tools** extensions. On Windows, install CMake and Visual Studio's
**Desktop development with C++** workload, then select an **x64 MSVC** kit.
The Windows libraries, including Embree 4.3.3 and its TBB dependencies, are
bundled; no separate Embree installation or PATH changes are needed.
On Linux, install a C++ compiler, GDB, CMake, and the libraries listed in
[README_LINUX.md](README_LINUX.md).

- **Ctrl+Shift+B** configures a Debug build and builds all enabled projects.
- In **Run and Debug**, choose a lab or `project`, then press **F5** to build
  that target and start debugging. Set breakpoints by clicking beside a line number.
- **Ctrl+F5** builds and runs the selected configuration without debugging.

The launch configurations set the working directory so relative shader and scene
paths resolve correctly. Build files are generated in `build/`. The pathtracer uses
Embree 4 and OpenMP and is included in the build and F5 configurations.
On Windows, CMake finds `external/embree4` automatically and copies the required
DLLs beside the executables in `bin/`.

To build from a Windows terminal with Visual Studio 2022 installed:

```powershell
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Debug
```

If an existing build directory uses a different generator or architecture,
use a fresh build directory. Bundle provenance and license notices are in
[external/embree4/BUNDLE.md](external/embree4/BUNDLE.md).
