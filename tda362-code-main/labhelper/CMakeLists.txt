cmake_minimum_required ( VERSION 3.10 )

project ( labhelper )

# External libraries which need to be built.
add_subdirectory ( ${CMAKE_SOURCE_DIR}/external_src/imgui-1.51 ${CMAKE_CURRENT_BINARY_DIR}/imgui )
set_target_properties(imgui PROPERTIES FOLDER external)

if("${SDL2_LIBRARIES}" STREQUAL "")
    message(STATUS "SDL2_LIBRARIES wasn't set, manually setting to SDL2::SDL2")
    set(SDL2_LIBRARIES "SDL2::SDL2")
endif()

find_package ( SDL2 REQUIRED )
find_package ( glm REQUIRED )
if(LABHELPER_USE_MESA)
    set(MESA_ROOT "" CACHE PATH "Mesa installation prefix")
    set(GLEW_MESA_ROOT "${CMAKE_SOURCE_DIR}/build/mesa-deps/glew-2.2.0" CACHE PATH
        "Extracted GLEW source directory for the EGL loader")
    find_path(MESA_INCLUDE_DIR EGL/egl.h HINTS "${MESA_ROOT}/include"
        /opt/homebrew/opt/mesa/include /usr/local/opt/mesa/include)
    find_library(MESA_EGL_LIBRARY EGL HINTS "${MESA_ROOT}/lib"
        /opt/homebrew/opt/mesa/lib /usr/local/opt/mesa/lib)
    find_library(MESA_GL_LIBRARY GL HINTS "${MESA_ROOT}/lib"
        /opt/homebrew/opt/mesa/lib /usr/local/opt/mesa/lib NO_DEFAULT_PATH)
    if(NOT MESA_INCLUDE_DIR OR NOT MESA_EGL_LIBRARY OR NOT MESA_GL_LIBRARY)
        message(FATAL_ERROR "Mesa EGL/OpenGL was not found. Run setup-macos.sh (brew install mesa).")
    endif()
    if(NOT EXISTS "${GLEW_MESA_ROOT}/src/glew.c")
        message(FATAL_ERROR "Run setup-macos.sh to download the GLEW loader source, or set GLEW_MESA_ROOT.")
    endif()
    # The Homebrew GLEW binary resolves Apple's entry points; use EGL for Mesa.
    # GLEW 2.2 accidentally excludes EGL's extension helpers on Apple.
    # Fix the generated build copy, leaving the downloaded source untouched.
    file(READ "${GLEW_MESA_ROOT}/src/glew.c" _glew_source)
    string(REPLACE "#if !defined(__APPLE__) || defined(GLEW_APPLE_GLX)"
        "#if !defined(__APPLE__) || defined(GLEW_APPLE_GLX) || defined(GLEW_EGL)"
        _glew_source "${_glew_source}")
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/glew_egl.c" "${_glew_source}")
    add_library(glew-mesa STATIC "${CMAKE_CURRENT_BINARY_DIR}/glew_egl.c")
    target_compile_definitions(glew-mesa PUBLIC GLEW_STATIC GLEW_NO_GLU PRIVATE GLEW_EGL)
    target_include_directories(glew-mesa PUBLIC "${GLEW_MESA_ROOT}/include" "${MESA_INCLUDE_DIR}")
    target_link_libraries(glew-mesa PUBLIC "${MESA_GL_LIBRARY}" "${MESA_EGL_LIBRARY}")
else()
    find_package ( GLEW REQUIRED )
    find_package ( OpenGL REQUIRED )
endif()

# Build and link library.
add_library ( ${PROJECT_NAME} 
    labhelper.h 
    labhelper.cpp 
    Model.h
    Model.cpp
    hdr.h
    hdr.cpp
    imgui_impl_sdl_gl3.h
    imgui_impl_sdl_gl3.cpp
    )

if(LABHELPER_USE_MESA)
    target_sources(${PROJECT_NAME} PRIVATE mesa_window.cpp)
    target_compile_definitions(${PROJECT_NAME} PUBLIC LABHELPER_USE_MESA)
    target_link_libraries(${PROJECT_NAME} PUBLIC glew-mesa)
    if(BUILD_TESTING AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/CMakeLists.txt")
        add_subdirectory(tests)
    endif()
endif()

if (MSVC)
	set(CMAKE_CXX_FLAGS_DEBUG_MODEL "/O2")
	string(REPLACE "/RTC1" "" CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}")
else()
	set(CMAKE_CXX_FLAGS_DEBUG_MODEL "-O3")
endif()
set_property(SOURCE Model.cpp labhelper.cpp PROPERTY COMPILE_OPTIONS "$<$<CONFIG:Debug>:${CMAKE_CXX_FLAGS_DEBUG_MODEL}>")

target_include_directories( ${PROJECT_NAME}
    PUBLIC
    ${CMAKE_SOURCE_DIR}/labhelper
    ${CMAKE_SOURCE_DIR}/external_src/stb-master
    ${CMAKE_SOURCE_DIR}/external_src/tinyobjloader-1.0.6
    ${SDL2_INCLUDE_DIRS}
    ${GLM_INCLUDE_DIRS}
    )

target_link_libraries ( ${PROJECT_NAME}
    PUBLIC
    imgui
    ${SDL2_LIBRARIES}
    )

if(NOT LABHELPER_USE_MESA)
    target_include_directories(${PROJECT_NAME} PUBLIC ${GLEW_INCLUDE_DIRS} ${OPENGL_INCLUDE_DIR})
    target_link_libraries(${PROJECT_NAME} PUBLIC ${GLEW_LIBRARIES} ${OPENGL_LIBRARY})
endif()
if(TARGET glm::glm)
    target_link_libraries(${PROJECT_NAME} PUBLIC glm::glm)
endif()
