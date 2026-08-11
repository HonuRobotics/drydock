# maritime

ROS 2 Lyrical Luth (Ubuntu 26.04 "Resolute") + Gazebo Jetty, for the Honu Robotics maritime simulation stack: [gz-maritime](https://github.com/HonuRobotics/gz-maritime), [ehukai](https://github.com/HonuRobotics/ehukai), [bluerobotics_models](https://github.com/HonuRobotics/bluerobotics_models) and [holybro_models](https://github.com/HonuRobotics/holybro_models).

```bash
drydock build maritime
drydock run maritime
```

Uses the shared `docker/Dockerfile` — [apt-packages.txt](apt-packages.txt) is the only thing specific to this project.

The image carries apt packages and nothing else. No source, no rosdep run, no colcon. Your repositories live on the host and are bind-mounted in, so how they are checked out and built is documented by those repositories, not here.
