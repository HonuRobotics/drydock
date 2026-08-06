# drydock

> **Internal tooling.** This is the development environment Honu Robotics uses for its own ROS 2 / Gazebo work. It is public because there is nothing secret in it, not because it is a product: no support, no stability guarantees, may change without notice.

A single agreed development environment, as a Docker Compose recipe. Everyone gets the same ROS 2, the same Gazebo and the same system dependencies, so reviewing a colleague's branch is `gh pr checkout` and a rebuild rather than an afternoon of "works on my machine".

**The image replaces host configuration, not the developer.** It installs apt packages and nothing else — it imports no repositories, runs no `rosdep`, runs no `colcon`, and contains no source. Your workspace is bind-mounted from the host and you build it yourself, so an edit costs one package rebuild instead of a 20-minute image rebuild, and you can always see exactly what ran.

Descended from [dockwater](https://github.com/HonuRobotics/dockwater), which did the same job through [rocker](https://github.com/osrf/rocker) for Kinetic through Jazzy. The `--home`, `--user`, `--x11` and `--nvidia` behaviours you see reimplemented in the compose files are rocker's; dockwater remains the right tool for those older distros.

## Requirements

| | |
|---|---|
| Docker Engine | 20.10+ with Compose v2+ (`docker compose version`) |
| GPU (NVIDIA) | proprietary driver on the host + [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) |
| GUI | an X server on the host; a Wayland session works through XWayland |
| Host tools | none beyond Docker — even `vcstool` runs inside the container |

Linux only. Host networking, `/dev/dri`, `/tmp/.X11-unix` and the NVIDIA runtime have no equivalent on Docker Desktop for macOS.

The GPU is optional — without one you get Mesa's llvmpipe: everything works, slowly. Check the toolkit is wired into Docker before building:

```bash
docker run --rm --gpus all ubuntu nvidia-smi
```

If that prints your GPU you are ready. If it errors with `could not select device driver`, install the toolkit and run `sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker`.

## Quick start

```bash
git clone https://github.com/HonuRobotics/drydock.git && cd drydock
cp .env.example .env          # then set DRYDOCK_WS to your workspace path
./drydock build               # ~10-20 min the first time
./drydock ws sync             # clone the project's repositories into $DRYDOCK_WS/src
./drydock run rosdep install --from-paths src --ignore-src -y
./drydock run colcon build --merge-install
./drydock sim
```

Put the repo on your `PATH` (or symlink `drydock` into `~/.local/bin`) and you can run it from anywhere.

## Commands

| Command | What it does |
|---|---|
| `drydock build` | Build the image |
| `drydock shell` | Interactive shell in the workspace (the default) |
| `drydock run <cmd…>` | Run one command in the container |
| `drydock ws sync` | `vcs import` the project's repositories (safe to re-run) |
| `drydock ws pull` / `status` | Fast-forward / inspect every repository |
| `drydock doctor` | Report the effective environment and flag drift |
| `drydock sim`, `drydock headless` | Project shortcuts — see `projects/<name>/commands.sh` |

There is deliberately no `build`/`test` shortcut for the workspace: you type `colcon` yourself so you control the flags.

`drydock` prepares an X cookie the container can use, forwards your UID/GID, picks the GPU path, and falls back to `sudo docker` when your user is not in the `docker` group.

Plain `docker compose` works too — create the cookie file first, or Docker creates a *directory* at that path and `XAUTHORITY` pointing at a directory breaks every GUI:

```bash
touch /tmp/.docker.xauth
xhost +local:
set -a; . ./.env; set +a
USER_UID=$(id -u) USER_GID=$(id -g) docker compose -f docker/compose.yaml run --rm dev
```

## How it fits together

Your whole `$HOME` is bind-mounted at the same absolute path inside the container (rocker `--home`). That path identity is load-bearing: colcon bakes absolute paths into `install/setup.bash`, the `.dsv` environment hooks, CMake caches and RPATHs, so the host and the container have to agree on where the workspace is. It also means `build/` and `log/` stay visible on the host, which is where you actually read compile errors.

Two consequences worth knowing:

- **Build in the container only.** A host `colcon build` and a container `colcon build` sharing one `build/` will fight over CMake caches. If you need both, give one of them `--build-base build/host --install-base install/host`.
- `PYTHONNOUSERSITE=1` is set by default, so your host `~/.local/lib/python3*/site-packages` does not silently land on the container's `PYTHONPATH`. Unset it in `.env` if you want `pip install --user` to persist.

The container user is `honu` at UID 1000, renamed from the base image's existing UID-1000 user rather than added alongside it, so files you create keep your ownership and you get a real named user with passwordless `sudo`. `HOME` points at your host home, not `/home/honu`.

Gazebo is never named in an apt line. It arrives transitively through `ros-${ROS_DISTRO}-ros-gz` and the `ros-${ROS_DISTRO}-gz-*-vendor` packages, deliberately: `gz_waves` does `find_package(gz_sim_vendor)`, so the real vendor packages with their CMake shims are required.

## Adding a project

A project is three data files. Nothing outside `projects/` changes:

```
projects/<name>/
├── apt-packages.txt   # one package per line; ${ROS_DISTRO} is substituted
├── <name>.repos       # vcstool manifest
└── commands.sh        # optional named shortcuts
```

Then set `DRYDOCK_PROJECT=<name>` in `.env`. If a project ever needs genuinely different build *logic* rather than different data, drop a `projects/<name>/Dockerfile` in and teach the script to prefer it — but do that when it happens, not before.

## Reviewing a colleague's PR

The workflow this repo exists for:

```bash
cd $DRYDOCK_WS/src/gz-maritime && gh pr checkout 42    # host-side; your gh auth
drydock run colcon build --merge-install               # in the agreed image
drydock sim                                            # look at it
gh pr review 42 --approve
```

No image rebuild, and both of you are provably on the same environment because you are both on the `DRYDOCK_TAG` from `.env.example`. `drydock doctor` says so out loud when you are not.

## Verifying the GPU is actually being used

```bash
drydock run nvidia-smi                                     # the host GPU as the container sees it
drydock run glxinfo -B                                     # must name the discrete GPU
drydock run vulkaninfo --summary
```

Three outcomes, only one of which is right:

| `OpenGL renderer` | Meaning |
|---|---|
| `NVIDIA GeForce …` | Correct — the discrete GPU is rendering |
| `llvmpipe` | Software rendering: the GPU reservation or the `graphics` driver capability did not get through |
| An integrated GPU (`AMD Radeon 780M`, `Mesa Intel …`) | **Hybrid-laptop trap** — see below |

### The hybrid-laptop trap

On a laptop with a discrete NVIDIA GPU *and* an integrated one, everything looks healthy — `nvidia-smi` works in the container, `/dev/nvidia*` exists, the NVIDIA libraries are injected, the processes even open `/dev/nvidiactl` — while rendering silently runs on the **integrated** GPU. libglvnd resolves GLX to `libGLX_mesa`, which takes the `/dev/dri` render node the compose file maps in; `libGLX_nvidia` is never loaded. Open file descriptors on `/dev/nvidia*` prove nothing: libglvnd opens them just to *probe* the EGL vendor.

`docker/compose.nvidia.yaml` pins the vendor explicitly:

```yaml
__NV_PRIME_RENDER_OFFLOAD: 1
__GLX_VENDOR_LIBRARY_NAME: nvidia
__EGL_VENDOR_LIBRARY_FILENAMES: /usr/share/glvnd/egl_vendor.d/10_nvidia.json
```

To confirm from the host while the sim runs, watch both GPUs — only one should be busy:

```bash
nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader
cat /sys/class/drm/card*/device/gpu_busy_percent    # integrated GPU load
```

Conclusive: check which vendor library the process actually mapped.

```bash
grep -c libGLX_nvidia /proc/<gz-sim-pid>/maps   # 0 means Mesa won
```

Note that the NVIDIA **Vulkan** ICD is not injected by the container runtime (`/usr/share/vulkan/icd.d/` holds only Mesa ICDs), so the Vulkan render path lands on Mesa regardless. Gazebo's default OpenGL path is unaffected.

## Inspecting a running sim from the host

`network_mode: host` plus `ipc: host` put the container on the host's network and IPC namespaces, so host tooling can see straight into the simulation. ROS 2 needs nothing special beyond a matching distro and `ROS_DOMAIN_ID`:

```bash
source /opt/ros/lyrical/setup.bash
ros2 node list
ros2 topic hz /clock
```

Gazebo transport needs the container's partition. gz-transport defaults to `<hostname>:<username>`, and the container user is `honu`, not your host user — so `GZ_PARTITION` is pinned to `drydock` in `.env.example` and host-side inspection needs no lookup:

```bash
GZ_PARTITION=drydock gz topic -l
GZ_PARTITION=drydock gz topic -e -t /world/<world>/stats -n 1
```

Without a matching `GZ_PARTITION` the topic list comes back empty even though the sim is running perfectly.

One gotcha when measuring: `ros2 topic hz` block-buffers stdout when piped, so `timeout 5 ros2 topic hz /clock | tail` prints nothing and looks like a dead topic. Use `PYTHONUNBUFFERED=1`, or `ros2 topic echo --once`.

## Configuration

Everything lives in `.env` (copied from `.env.example`).

| Variable | Default | Purpose |
|---|---|---|
| `DRYDOCK_WS` | `${HOME}/vrx4_ws` | Your colcon workspace; also the container's working directory |
| `DRYDOCK_PROJECT` | `maritime` | Which `projects/<name>/` to use |
| `DRYDOCK_IMAGE` / `DRYDOCK_TAG` | `drydock` / dated tag | The agreed image. Change only by PR, with a CHANGELOG entry |
| `ROS_DISTRO` | `lyrical` | Base image tag and the distro built against |
| `USER_UID` / `USER_GID` | your host IDs | Ownership of files created in the mounted home |
| `ROS_DOMAIN_ID` | `0` | DDS domain |
| `ROS_AUTOMATIC_DISCOVERY_RANGE` | `LOCALHOST` | Keeps your sim off the office LAN |
| `GZ_PARTITION` | `drydock` | gz-transport partition, pinned for host-side inspection |
| `PYTHONNOUSERSITE` | `1` | Keeps host user site-packages off `PYTHONPATH` |
| `XAUTH_FILE` | `/tmp/.docker.xauth` | Where the X cookie is written |

## Troubleshooting

**`Authorization required, but no authorization protocol specified`** — the X cookie did not reach the container. Re-run through `./drydock`, or `xhost +local:` before a plain `docker compose run`.

**GUI never appears on a Wayland session** — `DISPLAY` must point at XWayland (`:0` typically). `echo $DISPLAY` on the host; if it is empty, run headless.

**`could not select device driver "" with capabilities: [[gpu]]`** — the NVIDIA Container Toolkit is missing, or Docker was not reconfigured after installing it. `drydock doctor` checks for this.

**Rendering works but is very slow** — check `glxinfo -B` as above. On a hybrid laptop you may have landed on the integrated GPU; see the trap above. Rendering on one GPU while the display is driven by the other adds a per-frame cross-GPU copy on top of the slower rendering.

**`Cannot locate rosdep definition`** — stale rosdep cache. `drydock run rosdep update` first, or rebuild with `drydock build --no-cache`.

**A package will not configure and the dependency is not in `apt-packages.txt`** — that is expected drift. Run `drydock run rosdep install --from-paths src --ignore-src -y`, then add what it installed to `projects/<name>/apt-packages.txt` and open a PR so the next build has it.

## Credits

Merged from two prototypes: `docker/` in [gz-maritime](https://github.com/HonuRobotics/gz-maritime) by Brian Bingham, and `docker/` on the `jrivero/docker` branch of [bluerobotics_models](https://github.com/HonuRobotics/bluerobotics_models) by Jose Luis Rivero. Both authors' commits are preserved in this repository's history.

## License

Apache-2.0. See [LICENSE](LICENSE).
