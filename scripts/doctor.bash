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
# Reports the effective environment and warns when it has drifted from the
# agreed one. "Single agreed development environment" is a social contract;
# this is the thing that makes a violation visible in a bug report.
set -uo pipefail

readonly HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; WARNINGS=$((WARNINGS + 1)); }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$*"; PROBLEMS=$((PROBLEMS + 1)); }
WARNINGS=0
PROBLEMS=0

IMAGE="${DRYDOCK_IMAGE:-drydock}:${DRYDOCK_TAG:-lyrical-maritime}"

echo
echo "drydock doctor"
echo "=============="
echo
echo "Configuration"
printf '  %-28s %s\n' "project"    "${DRYDOCK_PROJECT:-maritime}"
printf '  %-28s %s\n' "ROS distro" "${ROS_DISTRO:-lyrical}"
printf '  %-28s %s\n' "workspace"  "${DRYDOCK_WS:-<unset>}"
printf '  %-28s %s\n' "image"      "${IMAGE}"
printf '  %-28s %s\n' "uid:gid"    "${USER_UID:-$(id -u)}:${USER_GID:-$(id -g)}"
printf '  %-28s %s\n' "GPU path"   "${DRYDOCK_GPU_PATH:-<not determined>}"
echo

echo "Host"
if docker info >/dev/null 2>&1; then
  ok "docker $(docker version --format '{{.Server.Version}}' 2>/dev/null), compose $(docker compose version --short 2>/dev/null)"
else
  bad "cannot reach the Docker daemon as $(id -un)"
fi

if [ -n "${DISPLAY:-}" ]; then
  ok "DISPLAY=${DISPLAY}"
else
  warn "DISPLAY unset — GUI commands will not open a window (headless only)"
fi

if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
  warn "Wayland session — GUI needs XWayland; verify with 'xdpyinfo >/dev/null'"
fi

if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
  ok "NVIDIA driver: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
  if docker info --format '{{println .Runtimes}}' 2>/dev/null | grep -qw nvidia; then
    ok "nvidia container runtime registered with Docker"
  else
    warn "NVIDIA driver present but Docker has no nvidia runtime — falling back to the iGPU"
    warn "  fix: sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker"
  fi
else
  ok "no NVIDIA GPU — using /dev/dri (Intel/AMD) or software rendering"
fi

case "${HERE}" in
  "${HOME}"/*) ok "repository is under \$HOME, so the container can see it" ;;
  *) bad "${HERE} is outside \$HOME — the container cannot see this repository" ;;
esac
echo

echo "Workspace"
if [ -d "${DRYDOCK_WS:-/nonexistent}/src" ]; then
  n=$(find "${DRYDOCK_WS}/src" -maxdepth 2 -name .git -type d 2>/dev/null | wc -l)
  ok "${DRYDOCK_WS}/src (${n} repositories)"
  if [ -f "${DRYDOCK_WS}/install/setup.bash" ]; then
    ok "built (install/setup.bash present)"
  else
    warn "not built yet — drydock run colcon build --merge-install"
  fi
else
  warn "${DRYDOCK_WS:-<unset>}/src does not exist — drydock ws sync"
fi
echo

echo "Image"
if docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  created=$(docker image inspect --format '{{.Created}}' "${IMAGE}" | cut -dT -f1)
  ok "${IMAGE} present (built ${created})"
else
  bad "${IMAGE} not present — drydock build"
fi

# The agreed tag lives in .env.example and moves only by PR. A local .env that
# has drifted is the single most common reason two developers see different
# behaviour, so say so loudly.
if [ -f "${HERE}/.env.example" ] && [ -f "${HERE}/.env" ]; then
  agreed=$(grep -E '^DRYDOCK_TAG=' "${HERE}/.env.example" | cut -d= -f2-)
  mine=$(grep -E '^DRYDOCK_TAG=' "${HERE}/.env" | cut -d= -f2-)
  if [ -n "${agreed}" ] && [ "${agreed}" != "${mine}" ]; then
    warn "your .env pins DRYDOCK_TAG=${mine} but the agreed tag is ${agreed}"
    warn "  mention this in any bug report, or align and rebuild"
  else
    ok "DRYDOCK_TAG matches the agreed tag (${agreed})"
  fi
fi
echo

if [ "${PROBLEMS}" -gt 0 ]; then
  echo "${PROBLEMS} problem(s), ${WARNINGS} warning(s)."
  exit 1
fi
echo "OK — ${WARNINGS} warning(s)."
