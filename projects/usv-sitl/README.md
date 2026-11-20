# usv-sitl

Ubuntu 22.04 with the apt dependencies of ArduPilot Rover SITL (release Rover-4.7.2), for the [usv-autopilot](https://github.com/Field-Robotics-Lab/usv-autopilot) SITL setup guide (`usv-sitl/docs/getting-started/`).

```bash
drydock build usv-sitl
drydock run usv-sitl
```

Then follow the guide in that shell. The image carries apt packages and nothing else, as the ROS projects do: ArduPilot is cloned and built by the guide, inside the container. [apt-packages.txt](apt-packages.txt) is what ArduPilot's `install-prereqs-ubuntu.sh` installs with apt on jammy, so that script's apt step finds nothing to do. The project has its own [Dockerfile](Dockerfile) because the shared one is ROS 2 + Gazebo.

The container does not see your home directory. [config](config) sets `DRYDOCK_HOME` to the folder this drydock checkout is cloned into (the guide's working directory, e.g. `~/WorkingCopies/usv-autopilot`), mounted as the container's home instead. The guide clones `ardupilot` and `usv-autopilot` there from the host, so they are at the same paths inside the container. What ArduPilot's install script writes under `~` (pip `--user` into `~/.local`, `~/.bashrc`, `~/.ardupilot_env`) lands there as hidden files, not in your real home. So do not clone drydock straight into your home directory for this project.

To reset the container's Python tools and shell settings, delete those hidden files from the working directory and rerun the guide's install step.
