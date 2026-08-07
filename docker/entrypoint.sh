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
# Sources the ROS underlay, then execs the command.
#
# No workspace overlay is sourced: what you have built and whether you want it
# on the path is your business, and your shell config is in the mounted home.
#
# Note this runs for the container's main process (`sleep infinity`) and for
# `docker run`, but NOT for `docker compose exec` — the shells you actually
# work in get ROS from /etc/bash.bashrc and BASH_ENV instead, which is why the
# Dockerfile sets both.
set -e

source "/opt/ros/${ROS_DISTRO}/setup.bash"

exec "$@"
