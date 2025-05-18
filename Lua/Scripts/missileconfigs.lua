Deep_Lua.MissileConfigs = {
        example_missile_id = {
        MAX_STEERING_FORCE = 0.02,       -- Steer the missile towards the direction the cursor is pointing at, smaller num means the msl will try harder to maneuver when going closer to LOS
        MAX_CORRECTION_FORCE = 0.7,      -- Correct the missile flying path towards the LOS , larger num means the msl will try harder to go back to LOS
        MAX_ACCELERATION = 0.15,         -- Accelerate the missile in its current direction
        AVR_G_FORCE_MULTIPLIER = 3.0,    -- Decide how hard can the missile turn to LOS, larger means less maneuver ability
        TOLERANCE = 0.05,                -- Decide how much error from LOS, 0(0%) means it will not follow LOS, 1(100%) means it will try its best to follow LOS
        STEERAGE_MULTIPLIER = 0.80,      -- Decide how hard the missile can maneuver when in large , smaller num means less maneuver ability
        INIT_LAUNCH_SPEED = 8,           -- Initial launch speed
        DISABLE_RESISTANCE = false,      -- Will the missile take water resistance, Change this may lead to significant differences
        IS_AUTO_GUIDED = false,          -- Is the missile auto guided
        GUIDENCE_DELAY = 0.0,            -- Determine when will the missile start to guide to target
        LOCK_RANGE = 0,                  -- Only matters when missile is auto guided.
        CAN_LOST_LOS = true,             -- Decide if the missile will lost LOS when doing large maneuver
        FOV = 0.6                        -- Max Angel error between missile and target
    },
}