cmake_minimum_required ( VERSION 3.10 )

project ( pathtracer )

find_package ( embree 4 REQUIRED CONFIG )

function(copy_embree_runtime target)
    if(WIN32)
        add_custom_command(TARGET ${target} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:embree>"
                "${EMBREE_ROOT_DIR}/bin/tbb12.dll"
                "${EMBREE_ROOT_DIR}/bin/tbbmalloc.dll"
                "$<TARGET_FILE_DIR:${target}>"
            VERBATIM)
    endif()
endfunction()

# Homebrew's OpenMP runtime is keg-only. Help Apple Clang find it without global flags.
if(APPLE)
    if(POLICY CMP0074)
        cmake_policy(SET CMP0074 NEW)
    endif()
    find_path(OpenMP_CXX_INCLUDE_DIR omp.h HINTS
        "${OpenMP_ROOT}/include" "/opt/homebrew/opt/libomp/include" "/usr/local/opt/libomp/include")
    find_library(OpenMP_libomp_LIBRARY NAMES omp HINTS
        "${OpenMP_ROOT}/lib" "/opt/homebrew/opt/libomp/lib" "/usr/local/opt/libomp/lib")
endif()
find_package ( OpenMP REQUIRED COMPONENTS CXX )

# Find *all* shaders.
file(GLOB_RECURSE SHADERS
    "${CMAKE_CURRENT_SOURCE_DIR}/*.vert"
    "${CMAKE_CURRENT_SOURCE_DIR}/*.frag"
)
# Separate filter for shaders.
source_group("Shaders" FILES ${SHADERS})

# Build and link executable.
add_executable ( ${PROJECT_NAME}
    main.cpp
    Pathtracer.h
    Pathtracer.cpp
    sampling.h
    sampling.cpp
    HDRImage.h
    HDRImage.cpp
    embree.h
    embree.cpp
    material.h
    material.cpp
    ${SHADERS}
    )

target_link_libraries ( ${PROJECT_NAME} labhelper embree OpenMP::OpenMP_CXX )
config_build_output()
copy_embree_runtime(${PROJECT_NAME})

if(BUILD_TESTING AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/CMakeLists.txt")
    add_subdirectory(tests)
endif()
