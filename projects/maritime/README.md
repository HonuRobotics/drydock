# maritime

ROS 2 Lyrical Luth (Ubuntu 26.04 "Resolute") + Gazebo Jetty, for the Honu Robotics maritime simulation stack: [gz-maritime](https://github.com/HonuRobotics/gz-maritime), [encinowaves](https://github.com/HonuRobotics/encinowaves), [bluerobotics_models](https://github.com/HonuRobotics/bluerobotics_models) and [holybro_models](https://github.com/HonuRobotics/holybro_models).

```bash
drydock build maritime
drydock run maritime
```

Uses the shared `docker/Dockerfile` — [apt-packages.txt](apt-packages.txt) is the only thing specific to this project.

## EncinoWaves

`gz_waves_provider_fft` does `find_package(EncinoWaves REQUIRED)`. The image carries its build dependencies (`cmake`, `build-essential`, `libeigen3-dev`, `libtbb-dev`, `libimath-dev`) but not the library — check it out alongside your other repositories and `colcon build` handles it, since it has a `package.xml`.

If you never modify the library, a prebuilt package is available instead:

```bash
sudo sh -c "$(curl -fsSL https://packages.honurobotics.com/setup.sh)"
sudo apt install libencinowaves-dev
```

That pulls Eigen, TBB and Imath with it. Installing it in a running container is lost on `drydock stop`; add it to [apt-packages.txt](apt-packages.txt) to make it permanent.
