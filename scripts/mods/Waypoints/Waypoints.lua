local mod = get_mod("Waypoints")

mod.waypoints_ready = false
mod.waypoint_lifespan_in_seconds = mod:get("waypoint_lifetime")
mod.clear_waypoint_when_reached = mod:get("clear_waypoint_when_reached")

-- Update settings when changed
mod.on_setting_changed = function(setting_name)
	if setting_name == "waypoint_lifetime" then
		mod.waypoint_lifespan_in_seconds = mod:get("waypoint_lifetime")
	end
	if setting_name == "clear_waypoint_when_reached" then
		mod.clear_waypoint_when_reached = mod:get("clear_waypoint_when_reached")
	end
end

mod.tooltip_settings = {
	distance_from_center = {
		width = 128,
		height = 128
	}
}

mod.waypoints = {
	['bright_wizard'] = {
		name = "bright_wizard",
		waypoint_is_set = false,
		waypoint_should_follow = false,
		unit_to_follow = nil,
		waypoint_current_time = 0,
		waypoint_vector = Vector3(0,0,0)
	},
	['dwarf_ranger'] = {
		name = "dwarf_ranger",
		waypoint_is_set = false,
		waypoint_should_follow = false,
		unit_to_follow = nil,
		waypoint_current_time = 0,
		waypoint_vector = Vector3(0,0,0)
	},
	['empire_soldier'] = {
		name = "empire_soldier",
		waypoint_is_set = false,
		waypoint_should_follow = false,
		unit_to_follow = nil,
		waypoint_current_time = 0,
		waypoint_vector = Vector3(0,0,0)
	},
	['witch_hunter'] = {
		name = "witch_hunter",
		waypoint_is_set = false,
		waypoint_should_follow = false,
		unit_to_follow = nil,
		waypoint_current_time = 0,
		waypoint_vector = Vector3(0,0,0)
	},
	['wood_elf'] = {
		name = "wood_elf",
		waypoint_is_set = false,
		waypoint_should_follow = false,
		unit_to_follow = nil,
		waypoint_current_time = 0,
		waypoint_vector = Vector3(0,0,0)
	}
}

local SIZE_X = 1920
local SIZE_Y = 1080

mod.scenegraph_definition = {
	screen = {
		scale = "fit",
		position = {
			0,
			0,
			UILayer.hud
		},
		size = {
			SIZE_X,
			SIZE_Y
		}
	}
}

mod.center_position = {
	mod.scenegraph_definition.screen.size[1] * 0.5,
	mod.scenegraph_definition.screen.size[2] * 0.5
}

mod.SETTING_NAMES = {
	WAYPOINT_SET_HOTKEY = "waypoint_set_hotkey",
	-- WAYPOINT_SET_SELF_HOTKEY = "waypoint_set_self_hotkey",
}

local function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

-- Send waypoint set network event to all clients
mod:network_register("rpc_waypoint_set", function(sender_peer_id, waypoint_caster, waypoint_x, waypoint_y, waypoint_z)
	mod:waypoint_received(waypoint_caster, waypoint_x, waypoint_y, waypoint_z)
end)

-- Send waypoint SELF network event to all clients
--[[mod:network_register("rpc_waypoint_set_self", function(sender_peer_id, waypoint_caster, unit_to_follow)
	mod:waypoint_received_self(waypoint_caster, unit_to_follow)
end)--]]

-- Function to perform when a client receives the waypoint location
mod.waypoint_received = function(self, waypoint_caster, waypoint_x, waypoint_y, waypoint_z)
	mod.waypoints[waypoint_caster].waypoint_is_set = true
	mod.waypoints[waypoint_caster].waypoint_should_follow = false
	mod.waypoints[waypoint_caster].waypoint_current_time = 0
	mod.waypoints[waypoint_caster].waypoint_vector = Vector3Aux.box(nil, Vector3(waypoint_x, waypoint_y, waypoint_z))

	-- mod:echo("waypoint received...")
end

-- Function to perform when a client receives the waypoint SELF location
--[[mod.waypoint_received_self = function(self, waypoint_caster, unit_to_follow)
	mod.waypoints[waypoint_caster].waypoint_is_set = true
	mod.waypoints[waypoint_caster].waypoint_should_follow = true
	mod.waypoints[waypoint_caster].unit_to_follow = unit_to_follow
	mod.waypoints[waypoint_caster].waypoint_current_time = 0
	mod.waypoints[waypoint_caster].waypoint_vector = Vector3(0,0,0)

	-- mod:echo("waypoint SELF received...")
end--]]

-- Send waypoint removal network event to all clients
mod:network_register("rpc_waypoint_remove", function(sender_peer_id, waypoint_caster)
	mod:waypoint_removed(waypoint_caster)
end)

-- Function to perform when a client receives the waypoint location
mod.waypoint_removed = function(self, waypoint_caster)
	mod.waypoints[waypoint_caster].waypoint_is_set = false
	mod.waypoints[waypoint_caster].waypoint_should_follow = false
	mod.waypoints[waypoint_caster].waypoint_current_time = 0
	mod.waypoints[waypoint_caster].waypoint_vector = Vector3(0,0,0)

	-- mod:echo("waypoint removed...")
end

mod.get_current_character = function(self) 
	local player = Managers.player:local_player()
	local profile_index = player:profile_index()
	local profile_settings = SPProfiles[profile_index]
	local display_name = profile_settings.display_name

	-- Echo the display name of the character
	-- mod:echo(display_name)
	-- Echo the steam player's name
	--mod:echo(player._cached_name)

	return display_name
end

-- Sets a waypoint where the player is looking
mod.waypoint_set = function(self)
	if not mod:is_enabled() or not Managers.state.spawn.world then
		return
	end

	local character_name = mod.get_current_character()

	local player_manager = Managers.player
	local player = player_manager:local_player(1)
	local player_unit = player.player_unit
	local camera_position = Managers.state.camera:camera_position(player.viewport_name)
	local camera_rotation = Managers.state.camera:camera_rotation(player.viewport_name)
	local camera_direction = Quaternion.forward(camera_rotation)
	local filter = "filter_ray_projectile"
	local world = Managers.state.spawn.world
	local physics_world = World.get_data(world, "physics_world")
	local result = PhysicsWorld.immediate_raycast(physics_world, camera_position, camera_direction, 100, "all", "collision_filter", filter)

	if result then
		local num_hits = #result

		for i = 1, num_hits, 1 do
			local hit = result[i]
			local hit_actor = hit[4]
			local hit_unit = Actor.unit(hit_actor)
			local attack_hit_self = hit_unit == player_unit

			if not attack_hit_self then

				-- mod:echo('waypoint set')
				-- mod:echo(hit[1])

				mod:network_send("rpc_waypoint_set", "all", character_name, hit[1][1], hit[1][2], hit[1][3])

				return hit[1]
			end
		end
	else
			mod:network_send("rpc_waypoint_remove", "all", character_name)
	end
end

-- Sets a waypoint on the player's character
--[[mod.waypoint_set_self = function(self)
	if not mod:is_enabled() or not Managers.state.spawn.world then
		return
	end

	local character_name = mod.get_current_character()
	local player_manager = Managers.player
	local player = player_manager:local_player(1)
	local unit_to_follow = player.player_unit

	mod:network_send("rpc_waypoint_set_self", "all", character_name, unit_to_follow)

end
--]]

-- Hook to perform updates to UI
mod:hook("MatchmakingManager.update", function(func, self, dt, ...)
	mod:waypoint_render(dt)

	func(self, dt, ...)
end)

-- Render waypoints on update
mod.waypoint_render = function(self, dt)
	mod:pcall(function()
		if mod.waypoints_ready and Managers.world:world("level_world") then
			local num_waypoints_active = 0

			for _, charwp in pairs(mod.waypoints) do
				if charwp.waypoint_is_set then
					if not mod.waypoint_gui and Managers.world:world("top_ingame_view") then
						mod:create_gui()
					end
					if charwp.waypoint_current_time < mod.waypoint_lifespan_in_seconds then
						charwp.waypoint_current_time = charwp.waypoint_current_time + dt

						-- Increment waypoints var so we can position them properly
						num_waypoints_active = num_waypoints_active + 1

						-- mod:echo(waypoint_vector)

						local player = Managers.player:local_player()

						if player.player_unit then

							-- Vector3 position of the waypoint in the world
							local waypoint_position = Vector3(0,0,0)
							local waypoint_on_me = false

							-- If waypoint set to follow character, update the vector to the player_unit's position
							if charwp.waypoint_should_follow and charwp.unit_to_follow then
								waypoint_position = POSITION_LOOKUP[charwp.unit_to_follow]

								if charwp.unit_to_follow == player.player_unit then
									waypoint_on_me = true
								end
							-- Else, use the defined waypoint
							else
								waypoint_position = Vector3(charwp.waypoint_vector[1], charwp.waypoint_vector[2], charwp.waypoint_vector[3])
							end

							local world = Managers.world:world("level_world")
							local viewport = ScriptWorld.viewport(world, player.viewport_name)
							local camera = ScriptViewport.camera(viewport)
							local scale = UIResolutionScale()

							local waypoint_position2d, depth = Camera.world_to_screen(camera, waypoint_position)
							local player_pos = ScriptCamera.position(camera)

							local distance = Vector3.distance(player_pos, waypoint_position) / 5

							if mod.clear_waypoint_when_reached and distance < 0.4 and not waypoint_on_me then
								mod.clear_waypoint(charwp)
								return
							end

							local waypoint_size = math.max(64 / distance, 24)
							local waypoint_size_behind = 32

							local screen_width = RESOLUTION_LOOKUP.res_w
							local screen_height = RESOLUTION_LOOKUP.res_h
							local center_pos_x = screen_width / 2
							local center_pos_y = (screen_height / 2)

							local first_person_extension = ScriptUnit.extension(player.player_unit, "first_person_system")
							local player_rotation = first_person_extension:current_rotation()

							local player_direction_forward = Quaternion.forward(player_rotation)
							player_direction_forward = Vector3.normalize(Vector3.flat(player_direction_forward))

							local player_direction_right = Quaternion.right(player_rotation)
							player_direction_right = Vector3.normalize(Vector3.flat(player_direction_right))

							local offset = waypoint_position - player_pos

							local direction = Vector3.normalize(Vector3.flat(offset))

							local player_forward_dot = Vector3.dot(player_direction_forward, direction)
							local player_right_dot = Vector3.dot(player_direction_right, direction)

							local is_behind = (player_forward_dot < 0 and true) or false

							local x, y, is_clamped, is_behind = mod.get_floating_icon_position(waypoint_position2d[1], waypoint_position2d[2], player_forward_dot, player_right_dot)

							local icon_name = "class_icon_"..charwp.name

							if is_clamped or is_behind then
								if not waypoint_on_me then
										local arrow_size = Vector2(waypoint_size_behind,waypoint_size_behind)
										local icon_size = Vector2(waypoint_size_behind,waypoint_size_behind)
										local height_from_center = waypoint_position2d[2] - mod.center_position[2]
										local arrow_angle, offset_x, offset_y, offset_z = mod.get_arrow_angle_and_offset(player_forward_dot, player_right_dot, arrow_size, icon_size, height_from_center)

										local icon_loc_x = 0
										local icon_loc_y = 0

										local alpha = 255 - (255 * distance / 5)

										-- Show the waypoint icon on either the left or right side of the screen based on position
										-- relative to player's rotation
										if offset_x > 0 then
											--icon_loc_x = screen_width - (waypoint_size_behind * 2)
											icon_loc_x = center_pos_x + offset_x
										else
											--icon_loc_x = waypoint_size_behind
											icon_loc_x = center_pos_x + offset_x - waypoint_size_behind
										end

										icon_loc_x = x
										icon_loc_y = y

										-- Adjust the waypoint icon's y position based on how many waypoints are active
										center_pos_y = center_pos_y - (num_waypoints_active * waypoint_size_behind * 0.5)
										offset_y = num_waypoints_active * (waypoint_size_behind + 10)

										--Gui.bitmap(mod.waypoint_gui, icon_name, Vector2(icon_loc_x, icon_loc_y), Vector2(waypoint_size_behind, waypoint_size_behind), Color(255, 255, 255, 255))
										Gui.bitmap(mod.waypoint_gui, icon_name, Vector2(icon_loc_x, center_pos_y - offset_y), Vector2(waypoint_size_behind, waypoint_size_behind), Color(alpha, 255, 255, 255))
									end
								else
									Gui.bitmap(mod.waypoint_gui, icon_name, Vector2(waypoint_position2d[1], waypoint_position2d[2]), Vector2(waypoint_size, waypoint_size))
							end

							--[[if not is_behind then
								Gui.bitmap(mod.waypoint_gui, icon_name, Vector2(waypoint_position2d[1], waypoint_position2d[2]), Vector2(waypoint_size, waypoint_size))
							else
								Gui.bitmap(mod.waypoint_gui, icon_name, Vector2(center_pos_x - waypoint_size_behind, center_pos_y - waypoint_size_behind), Vector2(waypoint_size_behind, waypoint_size_behind))
							end--]]
						end
					else
						-- mod:echo('waypoint expired!')

						charwp.waypoint_is_set = false
						charwp.waypoint_current_time = 0
					end
				end
			end
		end
	end) -- end mod:pcall
end

-- https://github.com/Aussiemon/Vermintide-2-Source-Code/blob/9f98479071fe839dedf487ce8567e7d9492704c9/scripts/ui/hud_ui/floating_icon_ui.lua
-- Line 224
mod.get_floating_icon_position = function (screen_pos_x, screen_pos_y, forward_dot, right_dot)
	-- local root_size = UISceneGraph.get_size_scaled(mod.ui_scenegraph, "screen")
	local root_size = Vector2(RESOLUTION_LOOKUP.res_w, RESOLUTION_LOOKUP.res_h)
	local scale = RESOLUTION_LOOKUP.scale
	local scaled_root_size_x = root_size[1] * scale
	local scaled_root_size_y = root_size[2] * scale
	local scaled_root_size_x_half = scaled_root_size_x * 0.5
	local scaled_root_size_y_half = scaled_root_size_y * 0.5
	local screen_width = RESOLUTION_LOOKUP.res_w
	local screen_height = RESOLUTION_LOOKUP.res_h
	local center_pos_x = screen_width / 2
	local center_pos_y = screen_height / 2
	local x_diff = screen_pos_x - center_pos_x
	local y_diff = center_pos_y - screen_pos_y
	local is_x_clamped = false
	local is_y_clamped = false

	if math.abs(x_diff) > scaled_root_size_x_half * 0.9 then
		is_x_clamped = true
	end

	if math.abs(y_diff) > scaled_root_size_y_half * 0.9 then
		is_y_clamped = true
	end

	local clamped_x_pos = screen_pos_x
	local clamped_y_pos = screen_pos_y
	local is_behind = (forward_dot < 0 and true) or false
	local is_clamped = ((is_x_clamped or is_y_clamped) and true) or false

	if is_clamped or is_behind then
		local distance_from_center = mod.tooltip_settings.distance_from_center
		clamped_x_pos = scaled_root_size_x_half + right_dot * distance_from_center.width * scale
		clamped_y_pos = scaled_root_size_y_half + forward_dot * distance_from_center.height * scale
	else
		local screen_pos_diff_x = screen_width - scaled_root_size_x
		local screen_pos_diff_y = screen_height - scaled_root_size_y
		clamped_x_pos = clamped_x_pos - screen_pos_diff_x / 2
		clamped_y_pos = clamped_y_pos - screen_pos_diff_y / 2
	end

	local inverse_scale = RESOLUTION_LOOKUP.inv_scale
	clamped_x_pos = clamped_x_pos * inverse_scale
	clamped_y_pos = clamped_y_pos * inverse_scale

	return clamped_x_pos, clamped_y_pos, is_clamped, is_behind
end

mod.get_arrow_angle_and_offset = function (forward_dot, right_dot, arrow_size, icon_size, height_from_center)
	local static_angle_value = 1.57079633
	local offset_x = 0
	local offset_y = 0
	local offset_z = 0
	local angle = math.atan2(right_dot, forward_dot)

	if height_from_center < -400 and forward_dot > 0.6 then
		offset_y = -(icon_size[2] * 0.5 + arrow_size[2])
		static_angle_value = static_angle_value * 2
	elseif height_from_center > 400 and forward_dot > 0.6 then
		offset_y = icon_size[2] * 0.5 + arrow_size[2]
		static_angle_value = 0
	elseif angle > 0 then
		offset_x = icon_size[2] * 0.5 + arrow_size[2]
	elseif angle < 0 then
		offset_x = -(icon_size[2] * 0.5 + arrow_size[2])
		static_angle_value = -static_angle_value
	else
		offset_x, offset_y, offset_z = nil
		static_angle_value = 0
	end

	return static_angle_value, offset_x, offset_y, offset_z
end

mod.waypoint_gui = nil

-- Clear the waypoint (e.g. on level change or when a user reaches it)
mod.clear_waypoint = function (character_waypoint_to_clear)
	character_waypoint_to_clear.waypoint_is_set = false
	character_waypoint_to_clear.waypoint_current_time = 0
	character_waypoint_to_clear.waypoint = Vector3(0,0,0)
end

mod.clear_all_waypoints = function()
	for _, charwp in pairs(mod.waypoints) do
		mod.clear_waypoint(charwp)
	end
end

mod.create_gui = function(self)
	mod.ui_scenegraph = UISceneGraph.init_scenegraph(mod.scenegraph_definition)

	if Managers.world:world("top_ingame_view") then
		local top_world = Managers.world:world("top_ingame_view")

		-- Create a screen overlay with specific materials we want to render
		mod.waypoint_gui = World.create_screen_gui(top_world, "immediate",
			"material", "materials/Waypoints/class_icon_dwarf_ranger",
			"material", "materials/Waypoints/class_icon_wood_elf",
			"material", "materials/Waypoints/class_icon_witch_hunter",
			"material", "materials/Waypoints/class_icon_empire_soldier",
			"material", "materials/Waypoints/class_icon_bright_wizard"
			)
	end
end

mod.destroy_gui = function(self)
	if Managers.world:world("top_ingame_view") then
		local top_world = Managers.world:world("top_ingame_view")
		World.destroy_gui(top_world, mod.waypoint_gui)
		mod.waypoint_gui = nil
	end
end

-- Delete UI on unload
mod.on_unload = function(exit_game)
	mod.waypoints_ready = false

	for _, charwp in pairs(mod.waypoints) do
		charwp.waypoint_is_set = false
	end

	if mod.waypoint_gui and Managers.world:world("top_ingame_view") then
		mod:destroy_gui()
	end
end

mod.on_disabled = function(initial_call)
	mod.waypoint_gui = nil
	mod.waypoints_ready = false

	mod.clear_all_waypoints()

	mod:disable_all_hooks()
end

mod.on_enabled = function(initial_call)
	mod.waypoints_ready = true
	mod:echo('Waypoints initialized')
	mod:enable_all_hooks()
end

--[[
	Disable waypoints while in menus, renable when exiting menus
--]]

mod.mission_windows = {
	"MatchmakingStateIngame",
	"StartGameView", --Select Mission screens
	"VMFOptionsView", --VMF options
	--[["StartGameWindowAdventure",
	"StartGameWindowAdventureSettings",
	"StartGameWindowDifficulty",
	"StartGameWindowGameMode",
	"StartGameWindowLobbyBrowser",
	"StartGameWindowMission",
	"StartGameWindowMissionSelection",
	"StartGameWindowMutator",
	"StartGameWindowMutatorGrid",
	"StartGameWindowMutatorList",
	"StartGameWindowMutatorSummary",
	"StartGameWindowSettings",
	"StartGameWindowTwitchGameSettings",
	"StartGameWindowTwitchLogin",--]]

	"StateTitleScreenMainMenu",
	"CharacterSelectionView",
	"StartMenuView",
	"OptionsView",
	"HeroView"
}

for _, i in pairs(mod.mission_windows) do
	mod:hook(i ..".on_enter", function(func, ...)
		func(...)

		mod.waypoints_ready = false
	end)

	mod:hook(i ..".on_exit", function(func, ...)
		func(...)
		mod.waypoints_ready = true
	end)
end

-- Disable waypoints when exiting a level and clear them all
mod:hook("StateInGameRunning.on_exit", function(func, ...)
	func(...)

	mod.clear_all_waypoints()

	mod.waypoints_ready = false
end)

mod:hook("StateInGameRunning.event_game_started", function(func, ...)
	func(...)

	mod.waypoints_ready = true
end)