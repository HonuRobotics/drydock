# Named shortcuts for `drydock <name>`, sourced by the drydock script with the
# requested name as $1. Set DRYDOCK_CMD and return 0 for a name you know;
# return non-zero for one you do not.
#
# Deliberately thin. There is no `build` or `test` shortcut: you type colcon
# yourself so you control the flags and can see what ran. `drydock run <any
# command>` covers everything not listed here.

case "${1:-}" in
  sim)
    DRYDOCK_CMD="ros2 launch vrx_bringup simulation.launch.xml"
    ;;
  headless)
    DRYDOCK_CMD="ros2 launch vrx_bringup simulation.launch.xml gazebo_gui:=false"
    ;;
  *)
    return 1
    ;;
esac
return 0
