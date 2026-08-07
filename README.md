# drydock

> **Internal tooling.** This is an development environment for ROS 2 / Gazebo work. It is public because there is nothing secret in it, not because it is a product: no support, no stability guarantees, may change without notice.

The intent is as follows:

* A single agreed development environment, as a Docker Compose recipe. 
* An image that replaces just host configuration, not workspace setup.   Containers include apt packages and little else — it imports no repositories, runs no `rosdep`, runs no `colcon`, and contains no source. Your workspace is bind-mounted from the host and you build it yourself.   Increases transparency and introspection during development.

Three things: build an image, run it as a container, join that container from as many shells as you like.

## Requirements

| | |
|---|---|
| Docker Engine | 20.10+ with Compose v2+ (`docker compose version`) |
| GPU (NVIDIA) | proprietary driver on the host + [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) |
| GUI | an X server on the host; a Wayland session works through XWayland |
| Host tools | none beyond Docker |

Linux only. Host networking, `/dev/dri`, `/tmp/.X11-unix` and the NVIDIA runtime have no equivalent on Docker Desktop for macOS.

The GPU is optional — without one you get Mesa's llvmpipe: everything works - likely slow.

## Quick start

```bash
git clone https://github.com/HonuRobotics/drydock.git && cd drydock
./drydock doctor              # check the host is ready
./drydock build maritime      # build the project described in projects/maritime
./drydock run maritime        # starts the container, opens a shell
```

You are now in a shell with ROS 2 and Gazebo, in the same directory you started from, with your home directory mounted. Everything from here is as if you started from a clean host:

```bash
mkdir -p ~/ws/src && cd ~/ws/src
git clone https://github.com/HonuRobotics/gz-maritime.git
cd ~/ws
rosdep install --from-paths src --ignore-src -y
colcon build --merge-install
source install/setup.bash
ros2 launch vrx_bringup simulation.launch.xml
```

From another terminal, open more shells on that same container:

```bash
./drydock join maritime
```

Closing a shell leaves the container running. `./drydock stop maritime` removes it.

## Commands

```
drydock build  <project> [--distro D] [--tag T] [docker build args...] % CLAUDE: Add a no cache option to force rebuild
drydock run    <project> [--tag T]           start it and open a shell
drydock join   <project> [--tag T] [cmd...]  another shell in the same container
drydock stop   <project>                     remove the container
drydock doctor [project]                     host-side checks
```

| Flag | Default | |
|---|---|---|
| `--distro` | `lyrical` | ROS distro; picks the `ros:<distro>-ros-base` base image | % CLAUDE: I want the distro information to b a part of the configuration  in the project directory.   Present me with another option.
| `--tag` | the project name | Image is `drydock:<tag>` | % CLAUDE: Why would i use a tag?
| `--name` | `drydock-<project>` | Compose project name, so two projects can run at once | % CLAUDE: Explain to me in a sidebar - curious how this works.

`join` takes a command instead of opening a shell: `drydock join maritime colcon test`.

`drydock` adds four things to plain `docker compose`: an X cookie the container user can actually use, your UID/GID, GPU selection, and `sudo docker` when you are not in the `docker` group. The header of `docker/compose.yaml` shows the equivalent raw invocation if you would rather not use the wrapper.

Rebuilding is picked up automatically — `run` recreates the container when the image has changed.

## How it fits together

Your whole `$HOME` is bind-mounted % CLAUDE: What is the difference between bind-mounted and must mounted?
 at the same absolute path inside the container, and every session opens in the directory you invoked it from. 

Path identity is load-bearing. % CLAUDE: Explain this.
This is important because `colcon` includes absolute paths into `install/setup.bash`, the `.dsv` environment hooks, CMake caches and RPATHs, so the host and the container have to agree on where the workspace is. It also means `build/` and `log/` stay visible on the host.

`PYTHONNOUSERSITE=1` is set, so your host `~/.local/lib/python3*/site-packages` does not silently land on the container's `PYTHONPATH`.

The container user is `honu` at UID 1000, renamed from the base image's existing UID-1000 user rather than added alongside it, so files you create keep your ownership and you get a real named user with passwordless `sudo`. `HOME` points at your host home, not `/home/honu`.

Gazebo is never named in an apt line. It arrives transitively through `ros-${ROS_DISTRO}-ros-gz` and the `ros-${ROS_DISTRO}-gz-*-vendor` packages, deliberately: `gz_waves` does `find_package(gz_sim_vendor)`, so the real vendor packages with their CMake shims are required. % CLAUDE: Mentioning gz_waves here ties this to an external project.  Better to be more general.

## Projects

One directory per project under `projects/`. A project is a build-time argument, not stored state — nothing remembers which one you last used.

```
projects/<name>/
├── apt-packages.txt   # required; one package per line, ${ROS_DISTRO} substituted
└── Dockerfile         # optional
```

Adding packages to `apt-packages.txt` is how projects should normally differ. The optional `Dockerfile` for one that genuinely needs a different recipe — a different base image, say — and the script prefers it over `docker/Dockerfile` when present. Use it sparingly: [dockwater](https://github.com/HonuRobotics/dockwater) ended up with seven near-identical Dockerfiles that drifted apart, which is the outcome to avoid. A project that only wants extra layers can start `FROM drydock:<other>`. % CLAUDE: We might need to discuss how to do this better - see earlier comment about about having distro in the version controlled projects space.

## Verifying the GPU is actually being used

```bash
drydock join maritime nvidia-smi                # the host GPU as the container sees it
drydock join maritime glxinfo -B                # must name the discrete GPU
drydock join maritime vulkaninfo --summary
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
__NV_PRIME_RENDER_OFFLOAD=1
__GLX_VENDOR_LIBRARY_NAME=nvidia
__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
```

To confirm from the host while a sim runs, watch both GPUs — only one should be busy:

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

`network_mode: host` plus `ipc: host` put the container on the host's network and IPC namespaces, so host tooling can see straight into the simulation. ROS 2 needs nothing special beyond a matching distro:

```bash
source /opt/ros/lyrical/setup.bash
ros2 node list
ros2 topic hz /clock
```

Gazebo transport needs the container's partition. gz-transport defaults to `<hostname>:<username>`, and the container user is `honu`, not your host user:

```bash
GZ_PARTITION=$(hostname):honu gz topic -l
GZ_PARTITION=$(hostname):honu gz topic -e -t /world/<world>/stats -n 1
```

Without a matching `GZ_PARTITION` the topic list comes back empty even though the sim is running perfectly.

One gotcha when measuring: `ros2 topic hz` block-buffers stdout when piped, so `timeout 5 ros2 topic hz /clock | tail` prints nothing and looks like a dead topic. Use `PYTHONUNBUFFERED=1`, or `ros2 topic echo --once`.

## Troubleshooting

**`Authorization required, but no authorization protocol specified`** — the X cookie did not reach the container. Re-run through `./drydock`, or `xhost +local:` before a raw `docker compose` invocation.

**GUI never appears on a Wayland session** — `DISPLAY` must point at XWayland (`:0` typically). `echo $DISPLAY` on the host; if it is empty, run headless.

**`could not select device driver "" with capabilities: [[gpu]]`** — the NVIDIA Container Toolkit is missing, or Docker was not reconfigured after installing it. `drydock doctor` checks for this.

**Rendering works but is very slow** — check `glxinfo -B` as above. On a hybrid laptop you may have landed on the integrated GPU; see the trap above. Rendering on one GPU while the display is driven by the other adds a per-frame cross-GPU copy on top of the slower rendering.

**`Another world of the same name is running`** — a previous sim is still going in the container. `drydock join <project>` and look, or `drydock stop <project>` to clear everything.

**`Cannot locate rosdep definition`** — stale rosdep cache. `rosdep update` in the container first.

**A package will not configure because a dependency is missing** — install it in the container to keep moving, then add it to `projects/<name>/apt-packages.txt` and open a PR so the next build has it.

## Credits

Merged from two prototypes: `docker/` in [gz-maritime](https://github.com/HonuRobotics/gz-maritime) by Brian Bingham, and `docker/` on the `jrivero/docker` branch of [bluerobotics_models](https://github.com/HonuRobotics/bluerobotics_models) by Jose Luis Rivero. Both authors' commits are preserved in this repository's history.

Descended from [dockwater](https://github.com/HonuRobotics/dockwater), which did the same job through [rocker](https://github.com/osrf/rocker) for Kinetic through Jazzy — `build` / `run` / `join` is its shape, and the `--home`, `--user`, `--x11` and `--nvidia` behaviours reimplemented in the compose files are rocker's.

## License

Apache-2.0. See [LICENSE](LICENSE).
