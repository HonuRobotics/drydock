#!/usr/bin/env bash
# Copyright 2026 Honu Robotics
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
#
# Workspace source management.
#
#   drydock ws sync     vcs import --skip-existing (safe to re-run)
#   drydock ws pull     vcs pull  (fast-forward every repository)
#   drydock ws status   vcs status
#
# vcstool runs INSIDE the container, so there is nothing extra to install on
# the host. Your $HOME is mounted at the same path, so ~/.gitconfig, ~/.ssh and
# the gh CLI's config apply exactly as they do host-side, and repositories land
# on the host filesystem where your editor can see them.
#
# This never builds anything. Building is `drydock run colcon build ...`, so
# you choose the flags and can see what ran.
set -euo pipefail

readonly HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DRYDOCK_WS="${DRYDOCK_WS:-${HOME}/vrx4_ws}"
DRYDOCK_PROJECT="${DRYDOCK_PROJECT:-maritime}"
readonly MANIFEST="${HERE}/projects/${DRYDOCK_PROJECT}/${DRYDOCK_PROJECT}.repos"

if [ ! -f "${MANIFEST}" ]; then
  echo "ERROR: no manifest at ${MANIFEST}" >&2
  exit 1
fi

# The container sees these paths unchanged: $HOME is bind-mounted at the same
# absolute path, and both the workspace and this repository live under it.
case "${MANIFEST}:${DRYDOCK_WS}" in
  "${HOME}"/*:"${HOME}"/*) ;;
  *)
    echo "ERROR: both the workspace and this repository must live under \$HOME," >&2
    echo "       which is what gets mounted into the container." >&2
    echo "         workspace: ${DRYDOCK_WS}" >&2
    echo "         manifest:  ${MANIFEST}" >&2
    exit 1
    ;;
esac

action="${1:-sync}"
[ $# -gt 0 ] && shift

case "${action}" in
  sync)
    mkdir -p "${DRYDOCK_WS}/src"
    echo "==> vcs import ${MANIFEST} -> ${DRYDOCK_WS}/src" >&2
    # --skip-existing so re-running never clobbers a repository you have
    # checked out to a PR branch. Use `drydock ws pull` to move them forward.
    exec "${HERE}/drydock" run vcs import --skip-existing \
      --input "${MANIFEST}" "${DRYDOCK_WS}/src"
    ;;
  pull)
    exec "${HERE}/drydock" run vcs pull "${DRYDOCK_WS}/src"
    ;;
  status)
    exec "${HERE}/drydock" run vcs status "${DRYDOCK_WS}/src"
    ;;
  *)
    echo "usage: drydock ws {sync|pull|status}" >&2
    exit 2
    ;;
esac
