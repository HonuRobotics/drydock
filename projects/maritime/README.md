# maritime

The Honu Robotics maritime simulation stack: [gz-maritime](https://github.com/HonuRobotics/gz-maritime) (wave physics, rendering and ROS 2 integration), [encinowaves](https://github.com/HonuRobotics/encinowaves) (the spectral wave library behind the FFT provider), and the vehicle model repositories [bluerobotics_models](https://github.com/HonuRobotics/bluerobotics_models) and [holybro_models](https://github.com/HonuRobotics/holybro_models).

ROS 2 Lyrical Luth (Ubuntu 26.04 "Resolute") + Gazebo Jetty.

## Quick start

```bash
drydock build
drydock ws sync
drydock run rosdep install --from-paths src --ignore-src -y
drydock run colcon build --merge-install
drydock sim
```

## Shortcuts

| Command | Runs |
|---|---|
| `drydock sim` | `ros2 launch vrx_bringup simulation.launch.xml` |
| `drydock headless` | the same with `gazebo_gui:=false` |

Everything else is `drydock run <command>`.

## EncinoWaves

`gz_waves_provider_fft` does `find_package(EncinoWaves REQUIRED)`. EncinoWaves is checked out into the workspace by `drydock ws sync` and built there, because this team actively develops it — see the note in [maritime.repos](maritime.repos) for the manual build steps needed until it gains a `package.xml`.

If you never modify the library, a prebuilt package is available instead:

```bash
sudo sh -c "$(curl -fsSL https://packages.honurobotics.com/setup.sh)"
sudo apt install libencinowaves-dev
```

That pulls `libeigen3-dev`, `libtbb-dev` and `libimath-dev` with it. Do this inside the container (the change is lost on exit) or add it to [apt-packages.txt](apt-packages.txt) and rebuild.

## Gazebo version

Gazebo Jetty is never named in an apt line. It arrives transitively through `ros-lyrical-ros-gz` and the `ros-lyrical-gz-*-vendor` packages, which is deliberate: `gz_waves` does `find_package(gz_sim_vendor)`, so the real vendor packages (with their CMake shims) are required rather than a hand-rolled Gazebo install. Resolute has no standalone `gz-jetty` metapackage in the OSRF repo.
