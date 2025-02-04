#!/bin/bash
set -e # Quit script on error
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


# Build vcpkg
if [ ! -d "vcpkg" ]; then
    echo "Cloning vcpkg"
    git clone --depth 1 --branch 2021.05.12  https://github.com/microsoft/vcpkg.git vcpkg
fi

if [ ! -f "vcpkg/vcpkg" ]; then
    echo "Building vcpkg"
    cd vcpkg
    ./bootstrap-vcpkg.sh -disableMetrics
    cd "${SCRIPT_DIR}"
fi

cd vcpkg
./vcpkg install kissfft fmt crossguid sdl2 gl3w reproc gsl-lite concurrentqueue platform-folders catch2 --recurse

cd "${SCRIPT_DIR}"


# Build external dependencies and copy to build tree
echo "Building external binary dependencies..."
"${SCRIPT_DIR}"/external/linux_build_externals.sh

cp "${SCRIPT_DIR}"/external/build/aubio-prefix/src/aubio-build/aubio_onset "${SCRIPT_DIR}"/server/native/

mkdir -p "${SCRIPT_DIR}"/server/beam/tau/priv/
cp "${SCRIPT_DIR}"/external/build/sp_midi-prefix/src/sp_midi-build/*.so "${SCRIPT_DIR}"/server/beam/tau/priv/
cp "${SCRIPT_DIR}"/external/build/sp_link-prefix/src/sp_link-build/*.so "${SCRIPT_DIR}"/server/beam/tau/priv/

echo "Compiling native ruby extensions..."
ruby "${SCRIPT_DIR}"/server/ruby/bin/compile-extensions.rb

echo "Translating tutorial..."
ruby "${SCRIPT_DIR}"/server/ruby/bin/i18n-tool.rb -t

echo "Generating docs for the Qt GUI..."
cp "${SCRIPT_DIR}"/gui/qt/utils/ruby_help.tmpl "${SCRIPT_DIR}"/gui/qt/utils/ruby_help.h
ruby "${SCRIPT_DIR}"/server/ruby/bin/qt-doc.rb -o "${SCRIPT_DIR}"/gui/qt/utils/ruby_help.h

echo "Updating GUI translation files..."
PATH=`pkg-config --variable bindir Qt5`:$PATH lrelease "${SCRIPT_DIR}"/gui/qt/lang/*.ts

echo "Compiling Erlang/Elixir files..."
cd "${SCRIPT_DIR}"/server/beam/tau
MIX_ENV="${MIX_ENV:-prod}" mix local.hex --force
MIX_ENV="${MIX_ENV:-prod}" mix deps.get
MIX_ENV="${MIX_ENV:-prod}" mix release --overwrite

cp src/tau.app.src ebin/tau.app
cd "${SCRIPT_DIR}"
