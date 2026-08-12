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

The GPU is optional — without one you get Mesa's llvmpipe: everything works, just slowly.

## Quick start

```bash
git clone https://github.com/HonuRobotics/drydock.git && cd drydock
./drydock doctor              # check the host is ready
./drydock build maritime      # build the project described in projects/maritime
./drydock run maritime        # starts the container, opens a shell
```

You are now in a shell with ROS 2 and Gazebo, in the same directory you started from, with your home directory mounted. Everything from here is as if you started from a clean host, e.g., 

```bash
mkdir -p ~/ws/src && cd ~/ws/src
git clone https://github.com/HonuRobotics/gz-maritime.git
cd ~/ws
rosdep install --from-paths src --ignore-src -y
colcon build --merge-install
source install/setup.bash
ros2 launch kai_bringup simulation.launch.xml
```

From another terminal, open more shells on that same container:

```bash
./drydock join maritime
```

Closing a shell leaves the container running. `./drydock stop maritime` removes it.

## Commands

```
drydock build  <project> [docker build args...]
drydock run    <project>           start it and open a shell
drydock join   <project> [cmd...]  another shell, same container
drydock stop   <project>           remove the container
drydock doctor [project]           host-side checks
```

Everything a build needs comes from the project directory, so there are no flags to learn — the project name is the whole interface. The one exception is `--name N`, which overrides the Compose project name (see the sidebar below) if you want a second, independent container from the same image. You will rarely want it.

Anything else is handed straight to `docker compose build`, so the flags pass through:

```bash
drydock build maritime --no-cache       # force a full rebuild
drydock build maritime --pull           # refresh the base image first
drydock build maritime --progress=plain # full log instead of the collapsing view
```

`join` takes a command instead of opening a shell: `drydock join maritime colcon test`.

`drydock` adds four things to plain `docker compose`: an X cookie the container user can actually use, your UID/GID, GPU selection, and `sudo docker` when you are not in the `docker` group. The header of `docker/compose.yaml` shows the equivalent raw invocation if you would rather not use the wrapper.

Rebuilding is picked up automatically — `run` recreates the container when the image has changed.

> **Sidebar: what the Compose project name does**
>
> `docker compose -p <name>` namespaces everything a compose file creates. Containers are named `<name>-<service>-<index>`, so drydock's single `dev` service becomes `drydock-maritime-dev-1`, and any networks or volumes get the same prefix.
>
> That namespace is how `join` and `stop` find the right container without you naming it: they run the same `-p drydock-maritime` and Compose resolves `dev` to the container already running under it. It is also what lets two projects run side by side — `drydock-maritime-dev-1` and `drydock-other-dev-1` are unrelated as far as Compose is concerned, even though both came from the same `docker/compose.yaml`.
>
> The name defaults to `drydock-<project>`, so you never have to think about it. `docker ps --filter name=drydock` shows everything drydock has running.

## How it fits together

Your whole `$HOME` is bind-mounted into the container, and every session opens in the directory you invoked it from.


It is mounted **at the same absolute path** inside as outside. That matters because `colcon` writes absolute paths into `install/setup.bash`, the `.dsv` environment hooks, CMake caches and binary RPATHs.  Keeping the path identical means artifacts built inside work outside, and vice versa. `build/` and `log/` stay visible on the host.

`PYTHONNOUSERSITE=1` is set, so your host `~/.local/lib/python3*/site-packages` does not silently land on the container's `PYTHONPATH`.

The container user is `honu` at UID 1000, renamed from the base image's existing UID-1000 user rather than added alongside it, so files you create keep your ownership and you get a real named user with passwordless `sudo`. `HOME` points at your host home, not `/home/honu`.

Where a project uses Gazebo, it is never named in an apt line. It arrives transitively through `ros-${ROS_DISTRO}-ros-gz` and the `ros-${ROS_DISTRO}-gz-*-vendor` packages. That is deliberate: ROS packages that build against Gazebo `find_package()` the vendor packages rather than Gazebo itself, and it is those packages that carry the CMake shims making that work. Installing Gazebo directly would satisfy the libraries but not the shims.

## Projects

One directory per project under `projects/`, holding everything that makes that project different. 

```
projects/<name>/
├── config             # required; ROS_DISTRO and BASE_IMAGE
├── apt-packages.txt   # required; one package per line, ${ROS_DISTRO} substituted
└── Dockerfile         # optional; rarely needed
```

`config` is short and is version-controlled, so distro and base image a project builds against is a property of the project.   For example:

```bash
# projects/maritime/config
ROS_DISTRO=lyrical
BASE_IMAGE=ros:${ROS_DISTRO}-ros-base
```

`apt-packages.txt` provides the package list integrated in the shared `docker/Dockerfile`

The optional `Dockerfile` **replaces** the shared one — `docker/Dockerfile` is not read at all for that project. Use this option when a project needs different build *steps*, since different distro, base image and packages are already covered by the two files above.

Replacing it means taking on the three things `run` and `join` rely on:

- **A user at `USER_UID`:`USER_GID`, made the image's `USER`.** Compose does not set `user:`, so whatever the image ends on is who you are — leave it as root and everything you create in your home is root-owned.
- **ROS on `PATH` for non-login shells** — `/etc/bash.bashrc` plus `ENV BASH_ENV`. `docker compose exec` does not run the entrypoint, so this, not `entrypoint.sh`, is what puts `ros2` in front of you.
- **An entrypoint that `exec "$@"`, and `sleep` on `PATH`**, because the container is held open with `command: ["sleep", "infinity"]`.

The five build args (`BASE_IMAGE`, `ROS_DISTRO`, `PROJECT`, `USER_UID`, `USER_GID`) are passed either way, and the build context is the repository root, so `COPY projects/${PROJECT}/apt-packages.txt` works the same. 

A project that only wants extra layers can `FROM drydock:<other>` and inherit all three contracts for free.

### Adding a project

```bash
cp -r projects/maritime projects/rover
$EDITOR projects/rover/config projects/rover/apt-packages.txt
drydock build rover
```

This is also how you try a different ROS distro. There is deliberately no `--distro` flag: copying the directory and editing one line gives you a second image that coexists with the first, is reviewable in a diff, and is still there next month — where a flag would give you something nobody else can reproduce without being told what you typed.

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


## License

Apache-2.0. See [LICENSE](LICENSE).
