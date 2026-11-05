#!/bin/bash
# Guided setup for Apple Silicon Macs. Compatible with macOS's Bash 3.2.
# A student may invoke this file with sh, which puts macOS Bash in POSIX mode.
# Restart before that shell reaches Bash-only syntax such as process substitution.
if [ -z "${BASH_VERSION:-}" ] || shopt -oq posix; then
    exec /bin/bash "$0" "$@"
fi
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
brew_command=""
code_command=""
previous_build=""

fail() { echo "SETUP FAILED: $*" >&2; exit 1; }

usage() {
    echo "Usage: bash setup-macos.sh [--check-only] [--no-launch]"
    echo "Installs missing tools and extensions, builds the labs, and opens VS Code."
}

find_brew() {
    if [[ -x /opt/homebrew/bin/brew ]]; then
        brew_command=/opt/homebrew/bin/brew
    else
        brew_command="$(command -v brew || true)"
    fi
}

find_code() {
    code_command=""
    local candidate
    for candidate in "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
                     "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"; do
        if [[ -x "$candidate" ]]; then code_command="$candidate"; return; fi
    done
    code_command="$(command -v code || true)"
}

have_cpp_tools() {
    xcode-select -p >/dev/null 2>&1 && xcrun --find clang >/dev/null 2>&1 &&
        xcrun --show-sdk-path >/dev/null 2>&1
}

check_platform() {
    [[ "$(uname -s)" == Darwin ]] || fail "This setup is for macOS."
    [[ "$(uname -m)" == arm64 ]] ||
        fail "Use an Apple Silicon Mac with a native Terminal. Intel Macs need help from a lab assistant."
    local version
    version="$(sw_vers -productVersion)"
    [[ "${version%%.*}" -ge 15 ]] || fail "This setup requires macOS 15 or later. Ask a lab assistant about older versions."
    [[ "$EUID" -ne 0 ]] || fail "Run setup as your normal user, without sudo. Installers request permission when needed."
}

prepare_build_directory() {
    local build="$repo/build" cache="$repo/build/CMakeCache.txt"
    local source generator architecture system_file
    if [[ -f "$cache" ]]; then
        source="$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "$cache")"
        generator="$(sed -n 's/^CMAKE_GENERATOR:INTERNAL=//p' "$cache")"
        architecture="$(sed -n 's/^CMAKE_OSX_ARCHITECTURES:STRING=//p' "$cache")"
        if [[ -z "$architecture" ]]; then
            for system_file in "$build"/CMakeFiles/*/CMakeSystem.cmake; do
                [[ -f "$system_file" ]] || continue
                architecture="$(sed -n 's/^set(CMAKE_SYSTEM_PROCESSOR "\([^"]*\)")/\1/p' "$system_file")"
            done
        fi
        if [[ "$source" != "$repo" || "$generator" != 'Unix Makefiles' ||
              ( -n "$architecture" && "$architecture" != arm64 ) ]]; then
            previous_build="$repo/build.previous.$(date +%Y%m%d-%H%M%S).$$"
            mv "$build" "$previous_build"
        fi
    fi
    mkdir -p "$build"
}

save_brew_path() {
    # GUI-launched VS Code and future terminals must also find Homebrew's tools.
    local line profile
    line="eval \"\$(\"$brew_command\" shellenv)\""
    case "${SHELL:-/bin/zsh}" in
        */bash) profile="$HOME/.bash_profile" ;;
        */zsh) profile="${ZDOTDIR:-$HOME}/.zprofile" ;;
        *) echo "For future terminals, add this to your shell startup file: $line"; return ;;
    esac
    if ! grep -Fqx "$line" "$profile" 2>/dev/null; then
        printf '\n# Homebrew tools for the graphics labs\n%s\n' "$line" >> "$profile"
        echo "Added Homebrew to $profile"
    fi
}

install_cpp_tools() {
    if have_cpp_tools; then echo "Apple C++ tools: already installed"; return; fi
    local answer
    echo "Apple's Command Line Tools need to be installed before setup can continue."
    echo "This is a normal first-time setup step, not an error."
    echo "Click Install in the macOS installer dialog (it may be behind Terminal)."
    xcode-select --install || true
    while true; do
        echo "Leave this Terminal window open while the installation finishes."
        if ! read -r -p "When it has finished, press Return to continue (or type q to stop): " answer; then
            echo "Setup paused. Run setup again when the Command Line Tools are installed."
            exit 0
        fi
        case "$answer" in
            q|Q)
                echo "Setup paused. Run setup again when you are ready."
                exit 0
                ;;
        esac
        if have_cpp_tools; then
            echo "Apple C++ tools: installed. Continuing setup..."
            return
        fi
        echo "The Command Line Tools are not ready yet. Finish the installer, then return here."
    done
}

install_homebrew() {
    find_brew
    if [[ -z "$brew_command" ]]; then
        echo "Installing Homebrew using its official installer. Follow its password and confirmation prompts."
        local installer="$repo/build/install-homebrew.sh"
        curl -fL --retry 3 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
        /bin/bash "$installer"
        find_brew
        [[ -n "$brew_command" ]] || fail "Homebrew installation did not finish. Run setup again after fixing the error above."
    fi
    [[ "$("$brew_command" --prefix)" == /opt/homebrew ]] ||
        fail "Expected native Homebrew in /opt/homebrew. Ask a lab assistant to check this installation."
    eval "$("$brew_command" shellenv)"
    save_brew_path
}

install_dependencies() {
    local package
    for package in cmake sdl2 glm mesa embree libomp; do
        if "$brew_command" list --versions "$package" >/dev/null 2>&1; then
            echo "$package: already installed"
        else
            "$brew_command" install "$package"
        fi
    done
    find_code
    if [[ -z "$code_command" ]]; then
        "$brew_command" install --cask visual-studio-code
        find_code
    fi
    [[ -n "$code_command" ]] || fail "VS Code was installed but could not be found. Run setup again."
    echo "Installing VS Code extensions..."
    "$code_command" --install-extension ms-vscode.cpptools
    "$code_command" --install-extension ms-vscode.cmake-tools
}

download_glew() {
    local deps="$repo/build/mesa-deps" checksum
    mkdir -p "$deps"
    if [[ ! -f "$deps/glew.tgz" ]]; then
        curl -fL --retry 3 https://github.com/nigels-com/glew/releases/download/glew-2.2.0/glew-2.2.0.tgz \
            -o "$deps/glew.tgz.download"
        mv "$deps/glew.tgz.download" "$deps/glew.tgz"
    fi
    checksum="$(shasum -a 256 "$deps/glew.tgz" | cut -d ' ' -f 1)"
    [[ "$checksum" == d4fc82893cfb00109578d0a1a2337fb8ca335b3ceccf97b97e5cc7f08e4353e1 ]] ||
        fail "GLEW download checksum failed. Remove build/mesa-deps/glew.tgz and rerun setup."
    if [[ ! -d "$deps/glew-2.2.0" ]]; then tar -xf "$deps/glew.tgz" -C "$deps"; fi
}

check_only() {
    local missing=0 package extensions
    if have_cpp_tools; then echo "Apple C++ tools: installed";
    else echo "Apple C++ tools: missing"; missing=1; fi
    find_brew
    if [[ -n "$brew_command" ]]; then
        echo "Homebrew: $brew_command"
        for package in cmake sdl2 glm mesa embree libomp; do
            if HOMEBREW_NO_AUTO_UPDATE=1 "$brew_command" list --versions "$package"; then :;
            else echo "$package: missing"; missing=1; fi
        done
    else echo "Homebrew and lab dependencies: missing"; missing=1; fi
    find_code
    if [[ -n "$code_command" ]]; then
        echo "VS Code: $code_command"
        extensions="$("$code_command" --list-extensions)"
        for package in ms-vscode.cpptools ms-vscode.cmake-tools; do
            if printf '%s\n' "$extensions" | grep -Fxiq "$package"; then echo "$package: installed";
            else echo "$package: missing"; missing=1; fi
        done
    else echo "VS Code and extensions: missing"; missing=1; fi
    echo "Prerequisite check complete. No tools installed or project files changed."
    return "$missing"
}

main() {
    local check=0 launch=1 option status log
    for option in "$@"; do
        case "$option" in
            --check-only) check=1 ;;
            --no-launch) launch=0 ;;
            --help|-h) usage; return ;;
            *) usage >&2; fail "Unknown option: $option" ;;
        esac
    done
    check_platform
    if [[ "$check" == 1 ]]; then check_only; return; fi
    prepare_build_directory
    log="$repo/build/setup-macos.log"
    exec > >(tee -a "$log") 2>&1
    trap 'status=$?; if [[ "$status" != 0 ]]; then echo "Setup did not finish. Fix the error above and rerun setup, or send build/setup-macos.log to a lab assistant."; fi' EXIT
    echo "Setting up the graphics labs ($(date))."
    echo "Existing tools are reused. Installers may ask for your Mac password."
    if [[ -n "$previous_build" ]]; then echo "Previous build saved in $previous_build"; fi
    install_cpp_tools
    install_homebrew
    install_dependencies
    download_glew
    echo "Configuring and building the labs..."
    cmake -S "$repo" -B "$repo/build" -G 'Unix Makefiles' \
        -DCMAKE_BUILD_TYPE=Debug -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DLABHELPER_USE_MESA=ON -DLABS_BUILD_PATHTRACER=ON \
        -DOpenMP_ROOT="$("$brew_command" --prefix libomp)" \
        -DMESA_ROOT="$("$brew_command" --prefix mesa)" \
        -DGLEW_MESA_ROOT="$repo/build/mesa-deps/glew-2.2.0"
    cmake --build "$repo/build" --target \
        lab1-rasterization lab2-textures lab3-camera lab4-shading \
        lab5-rendertotexture lab6-shadowmaps project pathtracer --parallel 4
    echo "Setup complete. In VS Code, trust the course folder if asked."
    echo "Open Run and Debug, select lab1-rasterization, and press F5."
    echo "If VS Code was already open, close all its windows and reopen the course folder to refresh its tools."
    echo "Setup log: $log"
    if [[ "$launch" == 1 ]]; then "$code_command" --new-window "$repo"; fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
