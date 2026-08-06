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
# Sources the ROS underlay and, if it exists, the mounted workspace's overlay,
# then execs the command. The overlay is sourced only if present: the workspace
# is bind-mounted from the host and may not be built yet, and the container
# must still start so you can build it.
set -e

source "/opt/ros/${ROS_DISTRO}/setup.bash"

# Both colcon install layouts are supported: the default isolated layout and
# --merge-install both produce ${DRYDOCK_WS}/install/setup.bash.
if [ -n "${DRYDOCK_WS:-}" ] && [ -f "${DRYDOCK_WS}/install/setup.bash" ]; then
  source "${DRYDOCK_WS}/install/setup.bash"
fi

exec "$@"
