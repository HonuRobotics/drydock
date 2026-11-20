# syntax=docker/dockerfile:1
#
# drydock usv-sitl image: Ubuntu 22.04 with ArduPilot Rover SITL's apt
# dependencies, for the usv-autopilot SITL setup guide.
#
# Replaces the shared docker/Dockerfile, which is ROS 2 + Gazebo. Like it, the
# image carries apt packages and nothing else: no ArduPilot source, no pip, no
# build. The guide clones and builds ArduPilot inside the container.
#
# Carries the three things `run` and `join` rely on (see the README): a user at
# USER_UID:USER_GID made the image's USER, `sleep` on PATH, and no entrypoint
# that would get in the way of the compose command. There is no ROS to put on
# PATH.

ARG BASE_IMAGE=ubuntu:22.04
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="drydock usv-sitl" \
      org.opencontainers.image.description="Ubuntu 22.04 + ArduPilot Rover SITL dependencies" \
      org.opencontainers.image.source="https://github.com/HonuRobotics/drydock" \
      org.opencontainers.image.licenses="Apache-2.0"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN rm -f /etc/apt/apt.conf.d/docker-clean

# ---- Packages -------------------------------------------------------------
ARG PROJECT=usv-sitl
COPY projects/${PROJECT}/apt-packages.txt /opt/drydock/apt-packages.txt
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    sed -e 's/#.*//' -e '/^[[:space:]]*$/d' /opt/drydock/apt-packages.txt \
      | xargs -r apt-get install -y --no-install-recommends && \
    ln -fs "/usr/share/zoneinfo/${TZ}" /etc/localtime && \
    echo "${TZ}" > /etc/timezone && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8

# The guide runs install-prereqs-ubuntu.sh, whose apt-get install needs an apt
# index. The one above lived in the cache mount and is gone from the image.
RUN apt-get update

# ---- Unprivileged user ----------------------------------------------------
# Same recipe as docker/Dockerfile. Ubuntu 22.04 has no UID 1000 user, so this
# normally takes the useradd branch.
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

ENV QT_X11_NO_MITSHM=1

# `docker compose exec` sets no USER, and install-prereqs-ubuntu.sh runs
# `usermod -a -G dialout $USER`, which fails (and stops the script) without it.
ENV USER=${USERNAME}

# The guide pip-installs MAVProxy with --user, into ~/.local/bin. On a desktop
# the login shell's ~/.profile puts that on PATH; drydock shells are not login
# shells, so do the same for every interactive shell here. Unconditionally:
# on a fresh home the folder only appears during the guide's Step 2, in a shell
# that has already started.
RUN echo 'PATH="$HOME/.local/bin:$PATH"' >> /etc/bash.bashrc

USER ${USERNAME}
CMD ["bash"]
