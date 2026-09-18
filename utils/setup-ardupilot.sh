# Source before running gz sim or sim_vehicle.py:
#
#     . ~/maritime_ws/tools/drydock/utils/setup-ardupilot.sh
#
# Set AP and AP_GZ first if your checkouts are somewhere other than the
# workspace's thirdparty/ directory.
AP=${AP:-$HOME/maritime_ws/thirdparty/ardupilot}
AP_GZ=${AP_GZ:-$HOME/maritime_ws/thirdparty/ardupilot_gazebo}

# Activate the venv FIRST. Sourcing activate restores PATH to its pre-venv
# value, so anything added before it is silently discarded.
[ "$VIRTUAL_ENV" = "$AP/venv-ardupilot" ] || . "$AP/venv-ardupilot/bin/activate"

export GZ_VERSION=jetty
export GZ_SIM_SYSTEM_PLUGIN_PATH=$AP_GZ/build${GZ_SIM_SYSTEM_PLUGIN_PATH:+:$GZ_SIM_SYSTEM_PLUGIN_PATH}
export GZ_SIM_RESOURCE_PATH=$AP_GZ/models:$AP_GZ/worlds${GZ_SIM_RESOURCE_PATH:+:$GZ_SIM_RESOURCE_PATH}
export SDF_PATH=$GZ_SIM_RESOURCE_PATH

case ":$PATH:" in
  *":$AP/Tools/autotest:"*) ;;
  *) export PATH="$AP/Tools/autotest:$PATH" ;;
esac
