# deepsea

ROS 2 Jazzy (Ubuntu 24.04 "Noble") + Gazebo Harmonic, for prototyping against orca4-derived AUV simulators that use ArduSub SITL.

```bash
drydock build deepsea
drydock run deepsea
```

Uses the shared `docker/Dockerfile`; [apt-packages.txt](apt-packages.txt) is the only thing specific to this project. ArduSub and `ardupilot_gazebo` are built from source in the workspace (`thirdparty/`), not in the image.
