# Quick Introduction To Doing The Graphics Labs in Linux

## Note
This is only recommended for people familiar and comfortable
with a Linux environment. Only limited support is provided, as not all
lab assistants may be able to answer your questions if you run into
problems.

The labs will *NOT* build on StuDAT computers since some of the external
libraries aren't available. This guide is meant for those of you that want
to run the labs on your own machines.

## Description
The labs are built with the build software CMake, which you will need to install.

You will also need to install the necessary third-party libraries needed for the labs. 
The libraries that you need are SDL2, GLEW and glm. You will also need to have an implementation of OpenGL 
installed on your system e.g. Mesa. 

You will also need Embree 4 and OpenMP for the pathtracer project.

Install CMake and these libraries with your package manager of choice:
```shell
apt-get install ...
yum install ...
pacman -S ...
...
```

If you are missing any necessary libraries CMake will complain when you are trying to build.

## Building and running in VS Code

Install VS Code, a C++ compiler (such as GCC), CMake, GDB, and the libraries
listed above. On Linux, the pathtracer uses the installed Embree 4 package.
The bundled Embree 4 binaries are for Windows x64 only.

1. Open the repository root folder in VS Code, using **File > Open Folder**
   or running `code .` from the repository root.
2. Install the recommended **C/C++** (`ms-vscode.cpptools`) and **CMake Tools**
   (`ms-vscode.cmake-tools`) extensions. If CMake Tools asks for a kit, select
   your installed compiler.
3. Press **Ctrl+Shift+B** to configure a Debug build and build all projects.
4. Open **Run and Debug** (**Ctrl+Shift+D**) and select a lab, `project`, or
   `pathtracer` from the launch configuration dropdown.
5. Press **F5** to build the selected target and start debugging, or
   **Ctrl+F5** to build and run without debugging.

Click beside a source line number to set a breakpoint. While debugging, use
**F10** to step over, **F11** to step into, and **Shift+F5** to stop.

The included `.vscode` configurations generate build files in `build/` and set
that directory as the working directory so shaders and scene assets can be
found. You do not need to run the terminal build commands below before using F5.

## Building from the terminal

Change directory to the root directory containing the labs.

Make a directory called 'build' and enter it:
``` shell
mkdir build
cd build
```

Prepare the build files by typing:
``` shell
cmake ..
```
or
``` shell
cmake -DCMAKE_BUILD_TYPE=Release ..
```

for a debug vs release build.

Now you can build the labs by simply typing:
``` shell
make
```

in the same directory.

The executable for each lab is now located in the corresponding directory in the build folder e.g. lab2-textures/lab2-textures.
