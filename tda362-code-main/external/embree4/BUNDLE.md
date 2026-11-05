# Embree 4.3.3 Windows x64 bundle

Source: https://github.com/RenderKit/embree/releases/tag/v4.3.3

Archive: https://github.com/RenderKit/embree/releases/download/v4.3.3/embree-4.3.3.x64.windows.zip

Archive SHA-256: `d4c07f88df9f009dd84e4e9b9dcec32ad7d96f927bd88de00b721b0923d481a9`

This is the prebuilt CPU package for Windows x64, used with MSVC. It requires
no Intel GPU or SYCL installation. Upstream headers, import libraries,
CMake package files, and DLLs are preserved without modification. Tutorial
executables, example models and source, and general documentation are omitted.
All license and third-party notice text files from the archive's `doc/`
directory are retained in `doc/` here and must accompany redistribution.

The runtime files are `bin/embree4.dll`, `bin/tbb12.dll`, and
`bin/tbbmalloc.dll`. CMake copies these next to the pathtracer and its test
executable, together with the repository's SDL2 and GLEW DLLs.

To update the bundle, replace `include/`, `lib/`, the DLLs in `bin/`, and the
license notices in `doc/` from an official CPU Windows x64 release. Update
this file and the root README, then build and run the Embree wrapper test in
both Debug and Release configurations.
