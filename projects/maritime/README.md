# maritime

ROS 2 Lyrical Luth (Ubuntu 26.04 "Resolute") + Gazebo Jetty, for the Honu Robotics maritime simulation stack: [gz-maritime](https://github.com/HonuRobotics/gz-maritime), [ehukai](https://github.com/HonuRobotics/ehukai), [bluerobotics_models](https://github.com/HonuRobotics/bluerobotics_models) and [holybro_models](https://github.com/HonuRobotics/holybro_models).

```bash
drydock build maritime
drydock run maritime
```

Uses the shared `docker/Dockerfile` — [apt-packages.txt](apt-packages.txt) is the only thing specific to this project.

## ehukai

`gz_waves_provider_fft` does `find_package(ehukai REQUIRED)`. The image carries its build dependencies (`cmake`, `build-essential`, `libeigen3-dev`, `libtbb-dev`, `libimath-dev`) but not the library — check it out alongside your other repositories and `colcon build` handles it, since it has a `package.xml`.

Build it from source. It is a library this team actively develops, so a prebuilt copy — whether baked into the image or installed from an apt repository — puts you on a version nobody else is looking at, and does it silently. There is no supported shortcut here on purpose.
