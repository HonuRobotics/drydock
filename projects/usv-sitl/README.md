# usv-sitl

Ubuntu 22.04 with the apt dependencies of ArduPilot Rover SITL (release Rover-4.7.2), for the [usv-autopilot](https://github.com/Field-Robotics-Lab/usv-autopilot) SITL setup guide (`usv-sitl/docs/getting-started/`).

```bash
drydock build usv-sitl
drydock run usv-sitl
```

Then follow the guide in that shell. The image carries apt packages and nothing else, as the ROS projects do: ArduPilot is cloned and built by the guide, inside the container. [apt-packages.txt](apt-packages.txt) is what ArduPilot's `install-prereqs-ubuntu.sh` installs with apt on jammy, so that script's apt step finds nothing to do. The project has its own [Dockerfile](Dockerfile) because the shared one is ROS 2 + Gazebo.

The container does not see your home directory. [config](config) sets `DRYDOCK_HOME=~/drydock-homes/usv-sitl`, mounted as the container's home instead, because the guide clones `~/ardupilot`, pip-installs MAVProxy with `--user` and edits `~/.bashrc`. Those land in `~/drydock-homes/usv-sitl` on the host, where host tools such as MATLAB can also read the SITL logs (`~/drydock-homes/usv-sitl/ardupilot/Rover/logs`).

To start over:

```bash
drydock stop usv-sitl
rm -rf ~/drydock-homes/usv-sitl
```
