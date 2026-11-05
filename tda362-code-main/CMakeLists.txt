cmake_minimum_required ( VERSION 3.10 )

project ( computer-graphics-labs )
include(CTest)

# Apple's native OpenGL driver cannot run the labs' OpenGL 4.5 code.
option(LABHELPER_USE_MESA "Render with Mesa llvmpipe and present through SDL" ${APPLE})
option(LABS_BUILD_PATHTRACER "Build the pathtracer (requires Embree 4 and OpenMP)" ON)
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

set(CMAKE_CONFIGURATION_TYPES "Debug;Release;RelWithDebInfo" CACHE STRING "" FORCE)

if(UNIX)
    set(OpenGL_GL_PREFERENCE "GLVND")
endif(UNIX)

# For windows we use our bundled binaries.
if(WIN32)
    if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8 OR CMAKE_SYSTEM_PROCESSOR MATCHES "^(ARM|arm|aarch)" OR CMAKE_GENERATOR_PLATFORM MATCHES "[Aa][Rr][Mm]")
        message(FATAL_ERROR "The bundled Windows libraries require an x64 build. Select an x64 MSVC kit or configure with -A x64.")
    endif()
    list(INSERT CMAKE_PREFIX_PATH 0 "${CMAKE_SOURCE_DIR}/external/embree4")
    list(APPEND CMAKE_PREFIX_PATH "${CMAKE_SOURCE_DIR}/external/sdl2")
    list(APPEND CMAKE_PREFIX_PATH "${CMAKE_SOURCE_DIR}/external/glew")
    list(APPEND CMAKE_PREFIX_PATH "${CMAKE_SOURCE_DIR}/external/glm")
endif(WIN32)

# Copy the shared graphics libraries next to executables, including tests.
function(copy_windows_runtime target)
    if(WIN32)
        add_custom_command(TARGET ${target} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CMAKE_SOURCE_DIR}/external/bin/SDL2.dll"
                "${CMAKE_SOURCE_DIR}/external/bin/glew32.dll"
                "$<TARGET_FILE_DIR:${target}>"
            VERBATIM)
    endif()
endfunction()

macro(config_build_output)
    copy_windows_runtime(${PROJECT_NAME})
    if(MSVC)
        set(DLL_DIRECTORIES "${CMAKE_SOURCE_DIR}/external/bin")
        set(MSVC_RUNTIME_DIR "${CMAKE_SOURCE_DIR}/bin")
        set_target_properties( ${PROJECT_NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY                "${MSVC_RUNTIME_DIR}" )
        set_target_properties( ${PROJECT_NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY_DEBUG          "${MSVC_RUNTIME_DIR}" )
        set_target_properties( ${PROJECT_NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY_RELEASE        "${MSVC_RUNTIME_DIR}" )
        set_target_properties( ${PROJECT_NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO "${MSVC_RUNTIME_DIR}" )
        set_target_properties( ${PROJECT_NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY_MINSIZEREL     "${MSVC_RUNTIME_DIR}" )
        set(vs_user_file "${PROJECT_BINARY_DIR}/${PROJECT_NAME}.vcxproj.user")
        string(REGEX REPLACE "v([0-9][0-9])([0-9])" "\\1.\\2" "VS_TOOLSET_VERSION" "${CMAKE_VS_PLATFORM_TOOLSET}")
        configure_file("${CMAKE_SOURCE_DIR}/VSUserTemplate.user" "${vs_user_file}" @ONLY)
    endif(MSVC)
endmacro(config_build_output)



add_definitions(-DGLM_ENABLE_EXPERIMENTAL)
add_definitions(-D_CRT_SECURE_NO_WARNINGS)
set ( CMAKE_EXPORT_COMPILE_COMMANDS ON )
set ( CMAKE_CXX_STANDARD 11 )
if( NOT CMAKE_BUILD_TYPE )
  set ( CMAKE_BUILD_TYPE DEBUG )
endif()

add_subdirectory ( labhelper )
add_subdirectory ( lab1-rasterization )
add_subdirectory ( lab2-textures )
add_subdirectory ( lab3-camera )
add_subdirectory ( lab4-shading )
add_subdirectory ( lab5-rendertotexture )
add_subdirectory ( lab6-shadowmaps )
if(LABS_BUILD_PATHTRACER)
    add_subdirectory ( pathtracer )
endif()
add_subdirectory ( project )
