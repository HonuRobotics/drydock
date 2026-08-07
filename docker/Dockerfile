# syntax=docker/dockerfile:1
#
# drydock development image: ROS 2 + Gazebo, GPU- and GUI-capable.
#
# This image provides the ENVIRONMENT and nothing else. It installs apt
# packages; it does not import repositories, run rosdep, or run colcon. The
# workspace is bind-mounted from the host at run time and you build it
# yourself, so an edit is a rebuild of one package rather than a rebuild of
# the image.
#
# The project-specific part is a single file: projects/<PROJECT>/apt-packages.txt.
# Adding a project means adding that file, not editing this one.
#
# GPU access is provided at run time by the NVIDIA container runtime; the
# NVIDIA_* variables below tell it to expose the graphics and display
# capabilities, not only compute. Without a GPU the image still runs on Mesa's
# llvmpipe software path (slow, but sensors still render).

# Both come from projects/<name>/config, so the distro and the base image a
# project builds against are version-controlled with the project rather than
# typed on the command line.
ARG BASE_IMAGE=ros:lyrical-ros-base
FROM ${BASE_IMAGE}
ARG ROS_DISTRO=lyrical

LABEL org.opencontainers.image.title="drydock" \
      org.opencontainers.image.description="Honu Robotics ROS 2 / Gazebo development environment" \
      org.opencontainers.image.source="https://github.com/HonuRobotics/drydock" \
      org.opencontainers.image.licenses="Apache-2.0"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# ARG, not ENV: keep noninteractive out of the runtime environment.
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# BuildKit cache mounts make repeated builds cheap. docker-clean would wipe the
# archive cache after every apt-get, defeating them.
RUN rm -f /etc/apt/apt.conf.d/docker-clean

# ---- Locale + base tooling ------------------------------------------------
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg lsb-release locales tzdata && \
    ln -fs "/usr/share/zoneinfo/${TZ}" /etc/localtime && \
    echo "${TZ}" > /etc/timezone && \
    locale-gen en_US en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ---- OSRF Gazebo apt repo -------------------------------------------------
# Provides Gazebo and the libs the gz_*_vendor packages depend on.
RUN curl -s https://packages.osrfoundation.org/gazebo.gpg \
      -o /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/gazebo-stable.list

# ---- Gazebo + ROS gz vendor shims + ros_gz --------------------------------
# The gz-*-vendor packages provide the CMake shims that gz_waves and friends
# find_package(). The quoted glob is passed literally to apt, which expands it
# to every ros-<distro>-gz-<x>-vendor package (msgs, transport, fuel-tools,
# sim, rendering, ...). Gazebo itself arrives via these vendor packages +
# ros-gz; Resolute (26.04) has no standalone `gz-jetty` metapackage in the OSRF
# repo, and installing one alongside the vendors would be redundant.
#
# These are NOT faked or built from source: gz_waves does
# find_package(gz_sim_vendor), so the real vendor packages are required.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      ros-${ROS_DISTRO}-ros-gz \
      "ros-${ROS_DISTRO}-gz-*-vendor" \
      ros-${ROS_DISTRO}-sdformat-vendor

# ---- Build tooling, dev tools, GL/Vulkan/X11 ------------------------------
# The ros:* base tags are not guaranteed to carry colcon/rosdep/vcstool.
# libglvnd is the dispatch layer the NVIDIA runtime injects libGLX_nvidia into;
# the mesa-* drivers stay as the no-GPU fallback. 64-bit only — Gazebo is
# 64-bit, so no i386 multiarch.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      python3-colcon-common-extensions \
      python3-rosdep \
      python3-vcstool \
      sudo \
      passwd \
      atop \
      expect \
      gdb \
      git \
      gnutls-bin \
      iputils-ping \
      less \
      net-tools \
      python3-dbg \
      python3-pip \
      python3-venv \
      vim \
      wget \
      xvfb \
      libglvnd0 \
      libgl1 \
      libglx0 \
      libegl1 \
      libgles2 \
      libglu1-mesa \
      libgl1-mesa-dri \
      libvulkan1 \
      mesa-vulkan-drivers \
      mesa-utils \
      vulkan-tools \
      libxau6 \
      libxdmcp6 \
      libxcb1 \
      libx11-6 \
      libxext6 \
      libxrender1 \
      libxrandr2 \
      libxi6 \
      libxcursor1 \
      libxinerama1 \
      libxkbcommon-x11-0 \
      x11-utils

# ---- Project packages -----------------------------------------------------
# The only project-specific layer. Hand-maintained on purpose: the source tree
# is not in the image, so `rosdep install --from-paths src` against the mounted
# workspace is what authoritatively resolves dependencies. This list just means
# you rarely have to wait for it. See the file's own header.
ARG PROJECT=maritime
COPY projects/${PROJECT}/apt-packages.txt /opt/drydock/apt-packages.txt
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    sed -e 's/#.*//' -e 's/\${ROS_DISTRO}/'"${ROS_DISTRO}"'/g' -e '/^[[:space:]]*$/d' \
        /opt/drydock/apt-packages.txt \
      | xargs -r apt-get install -y --no-install-recommends

# ---- Unprivileged user ----------------------------------------------------
# Matching the host UID/GID so files created in the bind-mounted home and
# workspace keep your ownership. Ubuntu 26.04 base images already ship a UID
# 1000 user, so rename it rather than colliding with it.
ARG USERNAME=honu
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
RUN set -eux; \
    if getent group "${USER_GID}" >/dev/null; then \
      current="$(getent group "${USER_GID}" | cut -d: -f1)"; \
      [ "${current}" = "${USERNAME}" ] || groupmod -n "${USERNAME}" "${current}"; \
    else \
      groupadd -g "${USER_GID}" "${USERNAME}"; \
    fi; \
    if getent passwd "${USER_UID}" >/dev/null; then \
      current="$(getent passwd "${USER_UID}" | cut -d: -f1)"; \
      if [ "${current}" != "${USERNAME}" ]; then \
        usermod -l "${USERNAME}" -d "/home/${USERNAME}" -m -g "${USER_GID}" "${current}"; \
      fi; \
    else \
      useradd -m -u "${USER_UID}" -g "${USER_GID}" -s /bin/bash "${USERNAME}"; \
    fi; \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}"; \
    chmod 0440 "/etc/sudoers.d/${USERNAME}"

# ---- Source ROS for interactive + non-interactive shells ------------------
# BASH_ENV makes every non-interactive `bash -c` source the ROS env too, so
# `drydock run <cmd>` and `docker exec ... bash -c` get ros2 on PATH.
# Caveat: this sources setup.bash even under scripts that run `set -u`, which
# can trip on unbound ROS vars — guard such a script with a localized `set +u`
# around its ROS calls if needed.
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" > /etc/profile.d/ros.sh \
 && chmod +x /etc/profile.d/ros.sh \
 && echo "source /etc/profile.d/ros.sh" >> /etc/bash.bashrc
ENV BASH_ENV=/etc/profile.d/ros.sh

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# NVIDIA container runtime hints. `all` covers compute+utility+graphics+display,
# and graphics/display are the ones ogre2 and the Qt GUIs actually need.
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all

# MIT-SHM does not survive the container/host X boundary; Qt falls back to plain
# X11 transport with this set.
ENV QT_X11_NO_MITSHM=1

USER ${USERNAME}
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
