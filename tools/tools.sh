#!/bin/bash
: "${LOCAL_BUILDS:=/tmp/local_builds}"
: "${BOTAN_VERSION:=2.18.2}"
: "${JSONC_VERSION:=0.12.1}"
: "${PYTHON_VERSION:=3.9.2}"
: "${AUTOMAKE_VERSION:=1.16.4}"
: "${CMAKE_VERSION=3.20.6-2}"
: "${MAKE_PARALLEL:=4}"

is_use_static_dependencies() {
  [[ -n "${USE_STATIC_DEPENDENCIES}" ]] && \
  [[ no    != "${USE_STATIC_DEPENDENCIES}" ]] && \
  [[ off   != "${USE_STATIC_DEPENDENCIES}" ]] && \
  [[ false != "${USE_STATIC_DEPENDENCIES}" ]] && \
  [[ 0     != "${USE_STATIC_DEPENDENCIES}" ]]
}

# Run its arguments inside a python-virtualenv-enabled sub-shell.
run_in_python_venv() {
  if [[ ! -e ~/.venv ]] || [[ ! -f ~/.venv/bin/activate ]]; then
      python3 -m venv ~/.venv
  fi

  (
    # Avoid issues like '_OLD_VIRTUAL_PATH: unbound variable'
    set +u
    . ~/.venv/bin/activate
    set -u
    "$@"
  )
}


install_cmake() {
  echo "Running install_cmake version ${CMAKE_VERSION} for ${ARCH}"
  local cmake_install=${LOCAL_BUILDS}/cmake
  mkdir -p ${cmake_install}
  pushd ${cmake_install}
  wget -nv https://github.com/xpack-dev-tools/cmake-xpack/releases/download/v${CMAKE_VERSION}/xpack-cmake-${CMAKE_VERSION}-linux-${ARCH}.tar.gz
  tar -zxf xpack-cmake-${CMAKE_VERSION}-linux-${ARCH}.tar.gz --directory /usr/local --strip-components=1 --skip-old-files
  popd
  rm -rf ${cmake_install}
}

build_and_install_python() {
  local python_build=${LOCAL_BUILDS}/python
  mkdir -p "${python_build}"
  pushd "${python_build}"
  wget -O python.tar.xz https://www.python.org/ftp/python/"${PYTHON_VERSION}"/Python-"${PYTHON_VERSION}".tar.xz
  tar -xf python.tar.xz --strip 1
  ./configure --enable-optimizations --prefix=/usr/local
  make -j"${MAKE_PARALLEL}" && sudo make install
  ensure_symlink_to_target /usr/bin/python3 /usr/bin/python
  popd
  rm -rf "${python_build}"
}

build_and_install_automake() {
  echo "Running build_and_install_automake version ${AUTOMAKE_VERSION}"
  local automake_build=${LOCAL_BUILDS}/automake
  mkdir -p "${automake_build}"
  pushd "${automake_build}"
  wget -O automake.tar.xz "https://ftp.gnu.org/gnu/automake/automake-${AUTOMAKE_VERSION}.tar.xz"
  tar -xf automake.tar.xz --strip 1
  ./configure --enable-optimizations --prefix=/usr/local
  make -j"${MAKE_PARALLEL}"
  sudo make install
  popd
  rm -rf "${automake_build}"
}

build_and_install_jsonc() {
  echo "Running build_and_install_jsonc version ${JSONC_VERSION}"
  local jsonc_build=${LOCAL_BUILDS}/json-c
  mkdir -p "${jsonc_build}"
  pushd "${jsonc_build}"
  wget https://s3.amazonaws.com/json-c_releases/releases/json-c-"${JSONC_VERSION}".tar.gz -O json-c.tar.gz
  tar xzf json-c.tar.gz --strip 1

  autoreconf -ivf
  local cpuparam=()
    [[ -z "$CPU" ]] || cpuparam=(--build="$CPU")
    local build_type_args=(
        "--enable-$(is_use_static_dependencies && echo 'static' || echo 'shared')"
        "--disable-$(is_use_static_dependencies && echo 'shared' || echo 'static')"
    )
    env CFLAGS="-fPIC -fno-omit-frame-pointer -Wno-implicit-fallthrough -g" ./configure ${cpuparam+"${cpuparam[@]}"} "${build_type_args[@]}" --prefix=/usr/local
    make -j"${MAKE_PARALLEL}"
    sudo make install
    popd
    rm -rf "${jsonc_build}"
}

build_and_install_botan() {
  local botan_build=${LOCAL_BUILDS}/botan

  git clone --depth 1 --branch "${BOTAN_VERSION}" https://github.com/randombit/botan "${botan_build}"

  local osparam=()
  local cpuparam=()
  local run=run
  local osslparam=()
  local modules=""
  [[ "${botan_v}" == "2" ]] && osslparam+=("--without-openssl") && modules=$(<ci/botan-modules tr '\n' ',')
  [[ "${botan_v}" == "3" ]] && modules=$(<ci/botan3-modules tr '\n' ',')

  pushd "${botan_build}"

  local extra_cflags="-fPIC"

  [[ -z "$CPU" ]] || cpuparam=(--cpu="$CPU" --disable-cc-tests)

  local build_target="shared,cli"
  is_use_static_dependencies && build_target="static,cli"

  run_in_python_venv ./configure.py --prefix=/usr/local --with-debug-info --extra-cxxflags="-fno-omit-frame-pointer -fPIC" \
      ${osparam+"${osparam[@]}"} ${cpuparam+"${cpuparam[@]}"} --without-documentation ${osslparam+"${osslparam[@]}"} --build-targets="${build_target}" \
      --minimized-build --enable-modules="$modules"
  make -j"${MAKE_PARALLEL}"
  sudo make install
  popd
  rm -rf "${botan_build}"
}

"$@"
