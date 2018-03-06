#!/usr/bin/env bash
# Copyright 2017 The TensorFlow Probability Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================
set -e

PLATFORM="$(uname -s | tr 'A-Z' 'a-z')"

function main() {
  if [ $# -lt 1 ] ; then
    echo "No destination dir provided"
    exit 1
  fi

  # Create the directory, then do dirname on a non-existent file inside it to
  # give us an absolute paths with tilde characters resolved to the destination
  # directory. Readlink -f is a cleaner way of doing this but is not available
  # on a fresh macOS install.
  mkdir -p "$1"
  DEST="$(dirname "${1}/does_not_exist")"
  echo "=== destination directory: ${DEST}"

  TMPDIR=$(mktemp -d -t tmp.XXXXXXXXXX)

  echo $(date) : "=== Using tmpdir: ${TMPDIR}"

  echo "=== Copy TensorFlow Probability files"
  # Here are bazel-bin/pip_pkg.runfiles directory structure.
  # bazel-bin/pip_pkg.runfiles
  # |- <maybe other directories generated by bazel build>
  # |- org_python_pypi_backports_weakref
  # |- org_tensorflow
  # |- protobuf
  # |- six_archive
  # |- tensorflow_probability
  #   |- external
  #   |- pip_pkg
  #   |- pip_pkg.sh
  #   |- MANIFEST.in (needed)
  #   |- setup.py (needed)
  #   |- tensorflow_probability (needed)
  #
  # To build tensorflow probability wheel, we only need setup.py, MANIFEST.in, and
  # python and .so files under tensorflow_probability/tensorflow_probability.
  # So we extract those to ${TMPDIR}.
  cp bazel-bin/pip_pkg.runfiles/tensorflow_probability/setup.py "${TMPDIR}"
  cp bazel-bin/pip_pkg.runfiles/tensorflow_probability/MANIFEST.in "${TMPDIR}"
  cp -R \
    bazel-bin/pip_pkg.runfiles/tensorflow_probability/tensorflow_probability \
    "${TMPDIR}"

  echo "=== Copy TensorFlow Probability root files"
  cp README.md ${TMPDIR}
  cp LICENSE ${TMPDIR}

  pushd ${TMPDIR}
  if [ "${TFL_SDIST}" = true ]; then
    echo $(date) : "=== Building source distribution and wheel"
  else
    echo $(date) : "=== Building wheel"
  fi

  # Pass through remaining arguments (following the first argument, which
  # specifies the output dir) to setup.py, e.g.,
  #  ./pip_pkg /tmp/tensorflow_probability_pkg --gpu --release
  # passes `--gpu --release` to setup.py.
  python setup.py sdist ${@:2} > /dev/null
  python setup.py bdist_wheel ${@:2} >/dev/null

  cp dist/* "${DEST}"
  popd
  rm -rf ${TMPDIR}
  echo $(date) : "=== Output tar ball and wheel file are in: ${DEST}"
}

main "$@"
