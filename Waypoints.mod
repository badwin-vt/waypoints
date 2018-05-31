return {
  run = function()
    local mod_resources = {
      mod_script       = "scripts/mods/Waypoints/Waypoints",
      mod_data         = "scripts/mods/Waypoints/Waypoints_data",
      mod_localization = "scripts/mods/Waypoints/Waypoints_localization"
    }
    new_mod("Waypoints", mod_resources)
  end,
  packages = {
    "resource_packages/Waypoints/Waypoints"
  }
}
