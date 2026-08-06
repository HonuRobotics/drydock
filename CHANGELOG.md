# Changelog

One entry per agreed image tag. This is the ledger for "the agreed development environment" — if `DRYDOCK_TAG` in `.env.example` moves, it moves here too, in the same PR.

## lyrical-maritime-20260806

Initial image, merged from `gz-maritime/docker` (Brian Bingham) and `bluerobotics_models@jrivero/docker` (Jose Luis Rivero).

- Base: `ros:lyrical-ros-base` — ROS 2 Lyrical Luth on Ubuntu 26.04 "Resolute".
- Gazebo Jetty, via `ros-lyrical-ros-gz` + `ros-lyrical-gz-*-vendor` + `ros-lyrical-sdformat-vendor` from `packages.osrfoundation.org` (`ubuntu-stable`).
- GL/Vulkan/X11 runtime for Gazebo's ogre2 path and the Qt GUIs, with Mesa as the no-GPU fallback.
- Container user `honu` at UID/GID 1000, with passwordless sudo.
- **New relative to `gz-maritime/docker`:** `cmake`, `build-essential`, `libeigen3-dev`, `libtbb-dev`, `libimath-dev` — the EncinoWaves build dependencies, which were missing even though `gz_waves_provider_fft` requires them.
- **Dropped relative to `bluerobotics_models@jrivero/docker`:** the baked overlay. Nothing is imported, resolved or built at image-build time.
- nav2 still absent — not yet released for Lyrical.
