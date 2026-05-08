if( ModIsEnabled( "mnee" )) then
	ModLuaFileAppend( "mods/mnee/bindings.lua", "mods/vector_core/mnee.lua" )
else return end

--documentation + examples
--example mod for tutorial module that teaches how to play the game

function OnWorldPreUpdate()
    dofile_once( "mods/mnee/lib.lua" )
    
    local global_init_speed = "VECTOR_INIT_CHAR_SPEED"
    local global_top_speed = "VECTOR_TOP_CHAR_SPEED"
    local global_bottom_speed = "VECTOR_BOTTOM_CHAR_SPEED"
    local global_friction = "VECTOR_BASELINE_FRICTION"
    local global_dash_delay = "VECTOR_DASH_DELAY_FRAMES"
    local global_always_run = "VECTOR_ALWAYS_RUN"
    local global_jump_bias = "VECTOR_JUMP_BIAS"
    local global_coyote_time = "VECTOR_COYOTE_TIME"
    local global_tutorial_list = "VECTOR_TUTORIAL_LIST"
    local global_tutorial_safety = "VECTOR_TUTORIAL_SAFETY"
    local global_tutorial_progress = "VECTOR_TUTORIAL_PROGRESS"
    local setting_tutorial_progress = "VECTOR.TUTORIAL_PROGRESS"
    local flag_second_life = "VECTOR_DAMAGE_PREVENTION_SAFETY"
    if( GameHasFlagRun( flag_second_life )) then GameRemoveFlagRun( flag_second_life ) end
    if( HasFlagPersistent( "never_spawn_this_action" )) then RemoveFlagPersistent( "never_spawn_this_action" ) end

    pen.c.vector_cntrls = pen.c.vector_cntrls or {}
    pen.c.vector_isjpad = pen.c.vector_isjpad or {}
    pen.c.vector_jpdpos = pen.c.vector_jpdpos or {}
    pen.c.vector_recoil = pen.c.vector_recoil or {}
    pen.c.vector_v_memo = pen.c.vector_v_memo or {}
    pen.c.vector_mnt_mm = pen.c.vector_mnt_mm or {}
    pen.c.vector_coytte = pen.c.vector_coytte or {}
    pen.c.vector_nrmavg = pen.c.vector_nrmavg or {}
    pen.c.vector_dashmm = pen.c.vector_dashmm or {}
    pen.c.vector_prcisn = pen.c.vector_prcisn or {}
    pen.c.vector_aangle = pen.c.vector_aangle or {}
    pen.c.vector_aasign = pen.c.vector_aasign or {}
    pen.c.vector_aaagun = pen.c.vector_aaagun or {}
    pen.c.vector_aimrrr = pen.c.vector_aimrrr or {}

    local function vector_effect()
        local frame_num = GameGetFrameNum()
        pen.t.loop( EntityGetWithTag( "vector_effect" ), function( i,effect_id )
            local timer = pen.magic_storage( effect_id, "vector_timer", "value_bool", nil, false )

            local is_removed = false
            local is_added = not( ComponentGetValue2( timer, "value_bool" ))
            if( is_added ) then ComponentSetValue2( timer, "value_bool", true ) end
            local death_frame = ComponentGetValue2( timer, "value_int" )
            if( death_frame > 0 ) then is_removed = death_frame < frame_num end

            pen.t.loop( EntityGetComponent( effect_id, "VariableStorageComponent" ), function( e,comp )
                if( ComponentGetValue2( comp, "name" ) ~= "vector_effect" ) then return end
                local path = ComponentGetValue2( comp, "value_string" )
                if( not( ModDoesFileExist( path ))) then return end
                dofile( path )( EntityGetRootEntity( effect_id ), effect_id, is_added, is_removed )
            end)

            if( is_removed ) then EntityKill( effect_id ) end
        end)
    end

    local function vector_stress( entity_id, injections_pre, injections_post )
        if( not( pen.magic_storage( entity_id, "vector_do_stress", "value_bool" ))) then return end
        local stress = pen.magic_storage( entity_id, "stress", "value_float", nil, 0 )

        pen.t.loop( injections_pre, function( i, injection )
            if( not( ModDoesFileExist( injection ))) then return end
            stress = dofile( injection )( entity_id, stress )
        end)

        --apply strength boost
        --get max_force
        --save it as stress_force_memo
        --write updated value to stress_force
        --if stress_force does not match with current max_force, add delta to stress_force_memo
        
        --degrades linearly, is uncapped but above certain values degrades exponentially

        --check for threats (use threat calc func, threat value progressively increase stress up until some value, the higher the threat, the higher this value)
        --incoming damage (compare hp values)
        --continous gunfire (check for fresh hooman-shot projectiles nearby)
        --total incoming adrenaline value must always increase else the benefits of it will decay

        --apply shader effects (extreme stress increases contrast and applies red hue shift)

        pen.t.loop( injections_post, function( i, injection )
            if( not( ModDoesFileExist( injection ))) then return end
            stress = dofile( injection )( entity_id, stress )
        end)
    end
    
    local function vector_handling( entity_id, injections_pre, injections_post )
        pen.c.vector_aimrrr[ entity_id ] = nil
        pen.c.vector_recoil[ entity_id ] = { 0, 0 }
        if( not( pen.magic_storage( entity_id, "vector_do_handling", "value_bool" ))) then return end

        local gun_id = pen.get_active_item( entity_id )
        local is_new = gun_id ~= pen.c.vector_aaagun[ entity_id ]
        if( is_new ) then pen.c.vector_aasign[ entity_id ] = nil end
        pen.c.vector_aaagun[ entity_id ] = gun_id

        if( not( pen.vld( gun_id, true ))) then return end
        if( pen.magic_storage( gun_id, "vector_no_handling", "value_bool" )) then return end

        local arm_id = pen.get_child( entity_id, "arm_r" )
        if( not( pen.vld( arm_id, true ))) then return end
        local abil_comp = EntityGetFirstComponentIncludingDisabled( gun_id, "AbilityComponent" )
        if( not( pen.vld( abil_comp, true ))) then return end
        local hot_comp = EntityGetFirstComponentIncludingDisabled( gun_id, "HotspotComponent", "shoot_pos" )
        if( not( pen.vld( hot_comp, true ))) then return end
        local char_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "CharacterDataComponent" )
        if( not( pen.vld( char_comp, true ))) then return end
        local ctrl_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "ControlsComponent" )
        if( not( pen.vld( ctrl_comp, true ))) then return end

        local jpad = pen.magic_storage( entity_id, "vector_jpad", "value_int" ) or 0

        local m_x, m_y = pen.get_mouse_pos( true, jpad )
        local arm_x, arm_y = EntityGetTransform( arm_id )
        local aim_x, aim_y = m_x - arm_x, m_y - arm_y

        local gun_mass = pen.get_mass( gun_id )
        local strength = pen.get_strength( entity_id )

        local gun_ratio = 100*( pen.rat( gun_mass, strength ) - 0.9 )
        local r1 = math.min( math.max( gun_ratio, 2.5 ), 10 )
        -- 2.5 5.8 6.7 9.2 10 | 3 1.5 1 0.5 0.1
        local h_aim = -0.52176696 + ( -711*r1/908 + 19606/997 - math.exp( -23236139/( 1000*r1 )) - 9574/( 431*( r1 - 842*math.exp( r1 )/3080117 )))/r1

        local gun_rating = strength*( pen.magic_storage( gun_id, "vector_handling", "value_float" ) or 1 )
        local r2 = math.min( math.max( math.abs( gun_rating ), 1 ), 150 )
        -- 1 45 75 90 150 | 2 1 0.5 0.3 0.1
        local h_recoil = 3*( r2 - 267/649 )*( 11*r2*( math.log( r2 ) - 1266/397 )/897 - 1585/219 )/911 + 145/72

        -- 0.1 0.5 1 1.5 3 | 1 4 8 10 20
        local arm_speed = math.max( math.floor( h_aim*math.exp( 461*( -h_aim - 797/996 )*( h_aim - 1757/759 )/619 ) + 1.00165701114382*math.exp( h_aim ) - 0.550125462611088 ), 3 )
        -- 0.1 0.5 1 1.5 3 | 1 3 8 15 30
        local hand_speed = math.max( math.floor( -463*( 733/885 - 4502*h_aim/651 )*( h_aim - 1/56 )/913 + math.pow( 508/67 - 2351*h_aim/987, h_aim ) - 86/421 ), 3 )

        local is_advanced = pen.c.vector_cntrls[ entity_id ]

        local this_sign = pen.sgn( aim_x )
        local this_angle = math.atan2( aim_y, aim_x )
        local last_angle = pen.c.vector_aangle[ entity_id ] or this_angle
        local sign_flip = this_sign ~= ( pen.c.vector_aasign[ entity_id ] or false )
        local aim_flip = ( h_aim < 0.9 or gun_rating < 0 ) and 0 or 3*( is_advanced and this_sign or 1 )

        local aim_delta = sign_flip and aim_flip or
            ( is_advanced and 1 or this_sign )*pen.adt( this_angle, last_angle )
        local aim_drift = aim_delta*math.min( h_aim, 1 )
        aim_drift = is_advanced and math.deg( aim_drift ) or 50*aim_drift
        pen.c.vector_aangle[ entity_id ], pen.c.vector_aasign[ entity_id ] = this_angle, this_sign

        --move recoil to the top
        --mass-based momentum for angular recoil
        --make weapon fly away at high recoil
        --two handed weapons (if the gun has front grip hotspot, 1.5*h_aim and 2*h_recoil if it is not enabled)

        local eid_x = arm_id.."x"
        local ix = pen.estimate( eid_x, 0, "exp"..arm_speed )
        local eid_y = arm_id.."y"
        local iy = pen.estimate( eid_y, 0, "exp"..arm_speed )
        local eid_r = arm_id.."r"
        pen.c.estimator_memo[ eid_r ] = ( pen.c.estimator_memo[ eid_r ] or 0 ) + aim_drift
        local r = pen.estimate( eid_r, 0, "exp"..(( is_advanced and 0.75 or 1 )*hand_speed ))

        local trans_comp = EntityGetFirstComponentIncludingDisabled( arm_id, "InheritTransformComponent" )
        local _, _, isx, isy, ir = ComponentGetValue2( trans_comp, "Transform" )

        pen.t.loop( injections_pre, function( i, injection )
            if( not( ModDoesFileExist( injection ))) then return end
            ix, iy, isx, isy, ir, r = dofile( injection )( entity_id, ix, iy, isx, isy, ir, r )
        end)

        ComponentSetValue2( trans_comp, "only_position", false )
        ComponentSetValue2( trans_comp, "Transform", ix, iy, isx, isy, ir )
        if( not( is_advanced )) then
            ComponentSetValue2( abil_comp, "item_recoil_rotation_coeff", r ) --make sure pen.gunshot knows the angle
        else pen.c.vector_aimrrr[ entity_id ] = this_angle - math.rad( r ) end

        if( ComponentGetValue2( abil_comp, "mItemRecoil" ) ~= 1 ) then
            ComponentSetValue2( abil_comp, "mItemRecoil", 1 )
        end

        local recoil_storage = pen.magic_storage( gun_id, "recoil" )
        if( not( pen.vld( recoil_storage, true ))) then return end
        local recoil = h_recoil*ComponentGetValue2( recoil_storage, "value_float" )
        if( pen.epc( recoil, 0 )) then return end

        local _,_,gun_r = EntityGetTransform( gun_id )
        local x,y,_,s_x = EntityGetTransform( entity_id )
        local tilt = 5*recoil*( 2 - math.min( math.max( 0.1, 100/strength - 0.2 ), 1.9 ))
        pen.c.estimator_memo[ eid_x ] = math.max( pen.c.estimator_memo[ eid_x ] - recoil, -7 )
        pen.c.estimator_memo[ eid_y ] = math.max( pen.c.estimator_memo[ eid_y ] - recoil, -7 )
        pen.c.estimator_memo[ eid_r ] = pen.c.estimator_memo[ eid_r ] + ( is_advanced and this_sign or 1 )*tilt

        local full_mass = pen.get_full_mass( entity_id )
        local push_force = 10*recoil/full_mass
        local will_hurt = push_force > 200

        local no_support = not( ComponentGetValue2( char_comp, "is_on_ground" ))
        if( push_force > 1.5 and no_support ) then push_force = 5*push_force*full_mass/4 end
        pen.c.vector_recoil[ entity_id ][1] = -push_force*math.cos( gun_r )
        pen.c.vector_recoil[ entity_id ][2] = -push_force*math.sin( gun_r )
        if( will_hurt ) then
            --apply stun effect
            EntityInflictDamage( entity_id, push_force/350, "DAMAGE_PHYSICS_HIT", "Could not handle the recoil.", "NORMAL", pen.c.vector_recoil[ entity_id ][1], pen.c.vector_recoil[ entity_id ][2], entity_id, x, y, push_force )
        end

        pen.t.loop( injections_post, function( i, injection )
            if( not( ModDoesFileExist( injection ))) then return end
            dofile( injection )( entity_id, full_mass, push_force )
        end)

        ComponentSetValue2( recoil_storage, "value_float", 0 )
    end
    
    --check for game effects
    local function vector_controls( entity_id, injections_pre, injections_post ) --partially stolen from IotaMP
        if( pen.magic_storage( entity_id, "vector_no_controls", "value_bool" )) then return end
        local ctrl_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "ControlsComponent" )
        if( not( pen.vld( ctrl_comp, true ))) then return end
        ComponentSetValue2( ctrl_comp, "enabled", false )

        local frame_num = GameGetFrameNum()
        local mroot = pen.magic_storage( entity_id, "vector_mroot", "value_string" ) or "vector_core"
        local function update_key( mnee_id, name, mode )
            local is_going = mnee_id
            if( type( is_going ) ~= "boolean" ) then
                is_going = mnee.mnin( "bind", { mroot, mnee_id }, { mode = mode })
            end
            
            local old_val = ComponentGetValue2( ctrl_comp, "mButtonDown"..name )
            if( is_going and not( old_val )) then
                ComponentSetValue2( ctrl_comp, "mButtonFrame"..name, frame_num + 1 ) end
            ComponentSetValue2( ctrl_comp, "mButtonDown"..name, is_going )
            return is_going
        end

        mnee.SPECIAL_KEYS[ "1gpd_r1" ], mnee.SPECIAL_KEYS[ "1gpd_l1" ] = true, true
        mnee.SPECIAL_KEYS[ "2gpd_r1" ], mnee.SPECIAL_KEYS[ "2gpd_l1" ] = true, true
        mnee.SPECIAL_KEYS[ "3gpd_r1" ], mnee.SPECIAL_KEYS[ "3gpd_l1" ] = true, true
        mnee.SPECIAL_KEYS[ "4gpd_r1" ], mnee.SPECIAL_KEYS[ "4gpd_l1" ] = true, true
        mnee.SPECIAL_KEYS[ "left_shift" ], mnee.SPECIAL_KEYS[ "left_ctrl" ] = nil, nil

        pen.t.loop( injections_pre, function( i, injection )
            if( not( ModDoesFileExist( injection ))) then return end
            dofile( injection )( entity_id )
        end)

        local movement = mnee.mnin( "stick", { mroot, "movement" }, { mode = "guied" })
        update_key( movement[1] < 0, "Left" ); update_key( movement[1] > 0, "Right" )
        update_key( movement[2] < 0, "Up" ); update_key( movement[2] > 0, "Down" )

        update_key( "run", "Run", "guied" )
        local jump = update_key( "jump", "Jump", "guied" )
        if( update_key( jump or mnee.mnin( "bind", { mroot, "fly" }, { mode = "guied" }), "Fly" )) then
            local _,new_y = EntityGetTransform( entity_id )
            ComponentSetValue2( ctrl_comp, "mFlyingTargetY", new_y - 10 )
        end

        update_key( "interact", "Interact", "guied" )
        update_key( "throw", "Throw", "guied" )
        update_key( "kick", "Kick", "guied" )

        local shot_main = update_key( "fire", "Fire", "guied" )
        local shot_also = update_key( "fire_alt", "Fire2", "guied" )
        if( shot_main or shot_also ) then
            ComponentSetValue2( ctrl_comp, "mButtonLastFrameFire", frame_num )
        end

        update_key( "inventory", "Inventory" )
        update_key( mnee.mnin( "key", "mouse_left", { mode = "guied" }), "LeftClick" )
        update_key( mnee.mnin( "key", "mouse_right", { mode = "guied" }), "RightClick" )
        
        if( frame_num - tonumber( GlobalsGetValue( pen.GLOBAL_INPUT_FRAME, "0" )) > 1 ) then
            local ms_x, ms_y = InputGetMousePosOnScreen()
            local _ms_x, _ms_y = ComponentGetValue2( ctrl_comp, "mMousePositionRaw" )
            ComponentSetValue2( ctrl_comp, "mMouseDelta", ms_x - _ms_x, ms_y - _ms_y )
            ComponentSetValue2( ctrl_comp, "mMousePositionRawPrev", _ms_x, _ms_y )
            ComponentSetValue2( ctrl_comp, "mMousePositionRaw", ms_x, ms_y )

            local aim = mnee.mnin( "stick", { mroot, "aim" }, { mode = "guied" })
            local x, y = EntityGetTransform( pen.get_child( entity_id, "arm_r" ) or entity_id )
            local mw_x, mw_y = x, y

            local jpad = mnee.bind2jpad( mroot, "aim_h" ) or 0
            local is_guied = GlobalsGetValue( pen.GLOBAL_JPAD_FOCUS..jpad, "" ) ~= ""
            local is_unscrolled = tonumber( GlobalsGetValue( pen.GLOBAL_UNSCROLLER_SAFETY, "0" )) == frame_num
            if( not( is_guied or is_unscrolled )) then
                local will_change_r = update_key( "next_item", "ChangeItemR" )
                ComponentSetValue2( ctrl_comp, "mButtonCountChangeItemR", pen.b2n( will_change_r ))
                local will_change_l = update_key( "last_item", "ChangeItemL" )
                ComponentSetValue2( ctrl_comp, "mButtonCountChangeItemL", pen.b2n( will_change_l ))
            end

            if( pen.c.vector_isjpad[ entity_id ]) then
                pen.c.vector_isjpad[ entity_id ] = pen.epc( ms_x, _ms_x ) and pen.epc( ms_y, _ms_y )
                pen.c.vector_jpdpos[ entity_id ] = pen.c.vector_jpdpos[ entity_id ] or { 0, 0 }

                if( math.abs( aim[1]) > 0.1 ) then pen.c.vector_jpdpos[ entity_id ][1] = aim[1] end
                if( math.abs( aim[2]) > 0.01 ) then pen.c.vector_jpdpos[ entity_id ][2] = aim[2] end

                local off_x, off_y = unpack( pen.c.vector_jpdpos[ entity_id ])
                local autoaim = not( mnee.mnin( "bind", { mroot, "halt_autoaim" }, { mode = "guied" }))
                angle = mnee.aim_assist( entity_id, { pen.get_creature_centre( entity_id )},
                    math.atan2( off_y, off_x ), autoaim, shot_main, { pic = "" })

                local off = 75*math.sqrt( off_x^2 + off_y^2 )
                mw_x, mw_y = x + off*math.cos( angle ), y + off*math.sin( angle )
                GlobalsSetValue( pen.GLOBAL_JPAD_MWD..jpad, pen.t.pack({ mw_x, mw_y, frame_num + 3 }))

                local pic_x, pic_y = pen.world2gui( mw_x, mw_y )
                pen.new.image( pic_x, pic_y, pen.Z.DEBUG - 11.11, "data/ui_gfx/mouse_cursor.png", { is_centered = true })

                if( mnee.mnin( "bind", { mroot, "focus_aim" }, { mode = "guied" })) then
                    pic_x, pic_y = pen.world2gui( x + 250*math.cos( angle ), y + 250*math.sin( angle )) end
                GlobalsSetValue( pen.GLOBAL_JPAD_MUI..jpad, pen.t.pack({ pic_x, pic_y, frame_num + 3 }))
            else
                pen.c.vector_isjpad[ entity_id ] = aim[1] ~= 0 or aim[2] ~= 0
                mw_x, mw_y = pen.get_mouse_pos( true )
                jpad = 0
            end
            
            pen.magic_storage( entity_id, "vector_jpad", "value_int", jpad )
            ComponentSetValue2( ctrl_comp, "mMousePosition", mw_x, mw_y )

            local aim_x, aim_y = mw_x - x, mw_y - y
            local aim_l = math.sqrt( aim_x^2 + aim_y^2 )
            local aim_r = pen.c.vector_aimrrr[ entity_id ] or math.atan2( aim_y, aim_x )
            ComponentSetValue2( ctrl_comp, "mAimingVectorNormalized", math.cos( aim_r ), math.sin( aim_r ))
            ComponentSetValue2( ctrl_comp, "mAimingVector", aim_l*math.cos( aim_r ), aim_l*math.sin( aim_r ))
        end

        pen.t.loop( injections_post, function( i, injection )
            if( not( ModDoesFileExist( injection ))) then return end
            dofile( injection )( entity_id )
        end)

        mnee.SPECIAL_KEYS[ "1gpd_r1" ], mnee.SPECIAL_KEYS[ "1gpd_l1" ] = nil, nil
        mnee.SPECIAL_KEYS[ "2gpd_r1" ], mnee.SPECIAL_KEYS[ "2gpd_l1" ] = nil, nil
        mnee.SPECIAL_KEYS[ "3gpd_r1" ], mnee.SPECIAL_KEYS[ "3gpd_l1" ] = nil, nil
        mnee.SPECIAL_KEYS[ "4gpd_r1" ], mnee.SPECIAL_KEYS[ "4gpd_l1" ] = nil, nil
        mnee.SPECIAL_KEYS[ "left_shift" ], mnee.SPECIAL_KEYS[ "left_ctrl" ] = true, true

        pen.c.vector_cntrls[ entity_id ] = true
    end

    local function vector_momentum( entity_id, injections_pre, injections_post )
        pen.c.vector_recoil[ entity_id ] = pen.c.vector_recoil[ entity_id ] or { 0, 0 }
        if( not( pen.magic_storage( entity_id, "vector_do_momentum", "value_bool" ))) then return end
        local char_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "CharacterDataComponent" )
        if( not( pen.vld( char_comp, true ))) then return end
        local plat_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "CharacterPlatformingComponent" )
        if( not( pen.vld( plat_comp, true ))) then return end
        local ctrl_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "ControlsComponent" )
        if( not( pen.vld( ctrl_comp, true ))) then return end

        local frame_num = GameGetFrameNum()
        local left = ComponentGetValue2( ctrl_comp, "mButtonDownLeft" )
        local right = ComponentGetValue2( ctrl_comp, "mButtonDownRight" )
        local jump = ComponentGetValue2( ctrl_comp, "mButtonFrameJump" ) == frame_num
        local run = ComponentGetValue2( ctrl_comp, "mButtonDownRun" )
        
        local x, y, _, s_x = EntityGetTransform( entity_id )
        local v_x, v_y = ComponentGetValue2( char_comp, "mVelocity" )
        local gravity = ComponentGetValue2( plat_comp, "pixel_gravity" )/60
        
        pen.t.loop( injections_pre, function( i, injection )
            if( not( ModDoesFileExist( injection ))) then return end
            left, right, jump, run, v_x, v_y, gravity =
                dofile( injection )( entity_id, { left, right, jump, run }, v_x, v_y, gravity )
        end)

        local did_mantle = pen.c.vector_mnt_mm[ entity_id ] or false
        local flip = s_x < 0; if( left or right ) then flip = left end
        local head_off = ComponentGetValue2( char_comp, "collision_aabb_min_y" )
        local feet_off = ComponentGetValue2( char_comp, "collision_aabb_max_y" )
        local body_off = ComponentGetValue2( char_comp, "collision_aabb_m"..( flip and "in" or "ax" ).."_x" )
        feet_off, body_off = feet_off - ( did_mantle and 0.5 or 3 ), body_off + 2*( flip and -1 or 1 )

        local init_speed = tonumber( GlobalsGetValue( global_init_speed, "7" ))
        local top_speed = tonumber( GlobalsGetValue( global_top_speed, "200" ))
        local bottom_speed = tonumber( GlobalsGetValue( global_bottom_speed, "20" ))
        local dash_delay = tonumber( GlobalsGetValue( global_dash_delay, "5" ))
        local jump_bias = tonumber( GlobalsGetValue( global_jump_bias, "20" ))
        local ctime = tonumber( GlobalsGetValue( global_coyote_time, "40" ))
        local decay = tonumber( GlobalsGetValue( global_friction, "0.99" ))
        
        local near_ground = RaytracePlatforms( x, y, x, y + 5 )
        local is_ground = ComponentGetValue2( char_comp, "is_on_ground" )
        local cdelta = math.max(( pen.c.vector_coytte[ entity_id ] or 0 ) - frame_num, 0 ) + 1
        local is_wall = RaytracePlatforms( x + body_off, y + head_off + 1, x + body_off, y + feet_off )
        is_wall = is_wall or ComponentGetValue2( char_comp, "mCollidedHorizontally" )
        if( is_ground ) then pen.c.vector_coytte[ entity_id ] = frame_num + ctime end
        is_ground = is_ground or cdelta > 1

        --reduce standstill friction if player holds down jump
        --if player times jumping with direction key opposite to v_x, flip the sign of v_x

        local is_mantling = false
        if((( left and s_x < 0 ) or ( right and s_x > 0 )) and is_wall ) then
            local check_x = x + 2*body_off
            local chest_off = ComponentGetValue2( char_comp, "buoyancy_check_offset_y" )
            local no_space = RaytracePlatforms( check_x, y + chest_off, check_x, y + head_off - 1 )
            no_space = no_space or RaytracePlatforms( check_x, y + head_off - 1, x, y + head_off - 1 )
            is_mantling = not( no_space or RaytracePlatforms( x, y + chest_off, check_x, y + chest_off ))
            if( is_mantling ) then v_y = math.max( -math.max( 7*gravity, math.abs( v_x )), v_y - 3*gravity ) end
        end

        local x_decay = is_wall and not( did_mantle )
        local y_transfer = is_wall and near_ground and jump
        v_x = x_decay and 0.9*(( pen.c.vector_v_memo[ entity_id ] or {})[1] or 0 ) or v_x
        v_y = y_transfer and v_y - ( gravity/2 + math.max( 10*gravity, math.abs( v_x ))) or v_y
        v_x, v_y = v_x + ( pen.c.vector_recoil[ entity_id ][1]), v_y + ( pen.c.vector_recoil[ entity_id ][2])
        if( not( is_mantling ) and did_mantle ) then v_x = v_x + 50*( flip and -1 or 1 ) end
        pen.c.vector_mnt_mm[ entity_id ] = is_mantling
        
        local strength = is_ground and math.log( 9*cdelta/ctime + 1, 10 )*pen.get_strength( entity_id ) or 0
        if( ComponentGetValue2( char_comp, "mJetpackEmitting" )) then
            strength = ComponentGetValue2( char_comp, "fly_velocity_x" )
        end

        local mass = pen.get_full_mass( entity_id ) --default is 1 which is considered 40kg
        mass = ( ComponentGetValue2( char_comp, "is_on_slippery_ground" ) and 2 or 1 )*mass

        --dash is too op, add cooldown or something
        --with this system the bhop momentum seems to decay
        local move_frame = pen.c.vector_dashmm[ entity_id ] or frame_num
        if( left or right ) then
            
            local always_run = GlobalsGetValue( global_always_run, "1" ) == "1"
            local force = strength*pen.rat( v_x, top_speed )*pen.rat( mass, strength )
            -- local will_dash = ( move_frame > frame_num ) and ( move_frame - frame_num < dash_delay )
            if( not( ComponentGetValue2( char_comp, "is_on_ground" )) or run == always_run ) then force = force/3 end
            -- if( will_dash ) then force = 5*force; pen.c.vector_prcisn[ entity_id ] = force end

            -- local prec = math.min( 1.25*( pen.c.vector_prcisn[ entity_id ] or init_speed ), 2*top_speed )
            -- if( is_ground ) then pen.c.vector_dashmm[ entity_id ] = frame_num + dash_delay + 5 end
            v_x = v_x + math.min( force, prec or force )*( right and 1 or -1 )
            -- pen.c.vector_prcisn[ entity_id ] = prec
        elseif( frame_num > move_frame ) then pen.c.vector_prcisn[ entity_id ] = init_speed end
        
        if( is_ground ) then
            local old_sign, k = pen.sgn( v_x ), 10
            if( math.abs( v_x ) < bottom_speed ) then k = k*pen.rat( v_x, 2*bottom_speed ) end
            v_x = v_x - k*pen.sgn( v_x )*math.abs( decay )*pen.rat( mass, strength )
            if( old_sign ~= pen.sgn( v_x )) then v_x = 0 end
        else v_x = decay*v_x end

        local jump_x, jump_y = 0, 0
        pen.hallway( function()
            if( not( is_ground or near_ground ) or did_mantle or is_mantling ) then return end

            local n_frames = 10
            if( not( pen.vld( pen.c.vector_nrmavg[ entity_id ]))) then
                pen.c.vector_nrmavg[ entity_id ] = {}
                for i = 1,n_frames do table.insert( pen.c.vector_nrmavg[ entity_id ], math.rad( 90 )) end
            end

            --do swimming manually (check if is in liquid through raytracing liquids and comparing to liquidless raytrace)
            
            local jump_angle = math.rad( -90 )
            local n_found, n_x, n_y, n_dist = GetSurfaceNormal( x, y + feet_off + 2, body_off + 5, 40 )
            if( n_found ) then
                local n_angle = math.atan2( n_y, n_x )
                table.remove( pen.c.vector_nrmavg[ entity_id ], 1 )
                table.insert( pen.c.vector_nrmavg[ entity_id ], n_angle )

                for i = 1,( n_frames - 1 ) do n_angle = n_angle + pen.c.vector_nrmavg[ entity_id ][i] end
                jump_angle = math.rad( 180 ) + ( n_angle + jump_bias*math.rad( 90 ))/( n_frames + jump_bias )
                jump_angle = jump_angle + ( flip and -1 or 1 )*math.rad(( left or right ) and 25 or 10 )
            end
            
            local jump_force = 4*strength*pen.rat( mass, strength )
            jump_x = math.abs( jump_force*math.cos( jump_angle ))
            jump_y = jump_force*math.sin( jump_angle )
        end)

        pen.t.loop( injections_post, function( i, injection )
            if( not( ModDoesFileExist( injection ))) then return end
            v_x, v_y, jump_x, jump_y = dofile( injection )( entity_id, strength, mass,
                { left, right, jump, run }, { is_ground, is_wall, is_mantling },
                { v_x, v_y, jump_x, jump_y, gravity })
        end)

        ComponentSetValue2( plat_comp, "jump_velocity_x", jump_x )
        ComponentSetValue2( plat_comp, "jump_velocity_y", jump_y )
        ComponentSetValue2( char_comp, "mVelocity", v_x, v_y )
        pen.c.vector_v_memo[ entity_id ] = { v_x, v_y }
        pen.c.vector_recoil[ entity_id ] = { 0, 0 }
    end

    local function vector_ctrl( entity_id )
        pen.t.loop( EntityGetComponent( entity_id, "VariableStorageComponent" ), function( i,comp )
            if( ComponentGetValue2( comp, "name" ) ~= "vector_ctrl" ) then return end
            local path = ComponentGetValue2( comp, "value_string" )
            if( not( ModDoesFileExist( path ))) then return end
            dofile( path )( entity_id )
        end)
    end

    local function vector_tutorial()
        local queue = pen.t.pack( GlobalsGetValue( global_tutorial_list, "" ))
        if( not( pen.vld( queue ))) then return end
        
        local guide = {}
        pen.t.loop( queue, function( i, file )
            if( not( ModDoesFileExist( file ))) then return end
            guide = dofile_once( file )( guide )
        end)
        if( not( pen.vld( guide ))) then return end
        
        local progress_global = pen.t.pack( pen.setting_get( setting_tutorial_progress ))
        local progress_local = pen.t.pack( GlobalsGetValue( global_tutorial_progress, "" ))
        if( not( pen.vld( progress_local ))) then
            progress_local = pen.vld( progress_global ) and progress_global or {{ "_", 0 }}
            GlobalsGetValue( global_tutorial_progress, pen.t.pack( progress_local ))
        end

        local module_id = ""
        local frame_num = GameGetFrameNum()
        progress_local = pen.t.unarray( progress_local )
        local step = pen.t.loop( pen.t.order( guide ), function( id, module )
            if( not( pen.ghf( module.is_active ))) then return end
            local safety = pen.t.pack( GlobalsGetValue( global_tutorial_safety, "|_|180|" ))
            if( safety[1] ~= id and safety[2] > frame_num ) then return end

            module_id = id
            local num = progress_local[ id ] or 1
            local out = pen.t.loop( module.steps, function( i, v )
                if( i ~= num ) then return end
                return v
            end)

            if( pen.vld( out )) then
                GlobalsSetValue( global_tutorial_safety, pen.t.pack({ id, frame_num + 60 }))
            end

            return out
        end)

        if( not( pen.vld( step ))) then return end

        local will_save = step.is_checkpoint
        local is_done = pen.ghf( step.is_done )
        if( not( step.is_pause )) then
			pen.c.estimator_memo = pen.c.estimator_memo or {}
            pen.c.vector_t_intr = pen.c.vector_t_intr or { module_id, frame_num + 5 }
            if( pen.c.vector_t_intr[1] ~= module_id or pen.c.vector_t_intr[2] < frame_num ) then
                pen.c.vector_t_intr[1] = module_id
                pen.c.estimator_memo[ "vector_tutorial_a" ] = nil
                pen.c.estimator_memo[ "vector_tutorial_o" ] = nil
                pen.c.estimator_memo[ "vector_tutorial_t" ] = nil
                pen.c.estimator_memo[ "vector_tutorial_x" ] = nil
                pen.c.estimator_memo[ "vector_tutorial_y" ] = nil
                pen.c.estimator_memo[ "vector_tutorial_w" ] = nil
                pen.c.estimator_memo[ "vector_tutorial_h" ] = nil
            end
            
            pen.c.vector_t_intr[2] = frame_num + 5
            
            local screen_x, screen_y = pen.get_screen_data()
            local pic_x, pic_y = unpack( pen.ghf( step.zone_xy, { screen_x, screen_y }))
            local zone_w, zone_h = unpack( pen.ghf( step.zone_wh, { screen_x, screen_y }))
            local alpha = pen.estimate( "vector_tutorial_a", { 100, 0 }, "exp5" )/100
            pic_x = pen.estimate( "vector_tutorial_x", { pic_x, -5 }, "wgt0.5" )
            pic_y = pen.estimate( "vector_tutorial_y", { pic_y, -5 }, "wgt0.5" )
            zone_w = pen.estimate( "vector_tutorial_w", { zone_w, screen_x }, "wgt0.5" )
            zone_h = pen.estimate( "vector_tutorial_h", { zone_h, screen_y }, "wgt0.5" )

            local function fog( pic_x, pic_y, zone_w, zone_h, screen_x, screen_y, alpha, density, can_click )
                density = density or 0.75

                pen.new.pixel( -5, -5,
                    pen.Z.TUTORIAL_SHADOW, pen.P.SHADOW, pic_x + 5, screen_y + 5, alpha*density )
                pen.new.pixel( pic_x, -5,
                    pen.Z.TUTORIAL_SHADOW, pen.P.SHADOW, zone_w, pic_y + 5, alpha*density )
                pen.new.pixel( pic_x + zone_w, -5,
                    pen.Z.TUTORIAL_SHADOW, pen.P.SHADOW, screen_x - ( pic_x + zone_w ) + 5, screen_y + 5, alpha*density )
                pen.new.pixel( pic_x, pic_y + zone_h,
                    pen.Z.TUTORIAL_SHADOW, pen.P.SHADOW, zone_w, screen_y - ( pic_y + zone_h ) + 5, alpha*density )

                if( can_click ) then return end

                pen.new.interface( -5, -5, pic_x + 5, screen_y + 5, pen.Z.TUTORIAL_SHADOW )
                pen.new.interface( pic_x, -5, zone_w, pic_y + 5, pen.Z.TUTORIAL_SHADOW )
                pen.new.interface( pic_x + zone_w, -5, screen_x - ( pic_x + zone_w ) + 5, screen_y + 5, pen.Z.TUTORIAL_SHADOW )
                pen.new.interface( pic_x, pic_y + zone_h, zone_w, screen_y - ( pic_y + zone_h ) + 5, pen.Z.TUTORIAL_SHADOW )
            end

            for i = 1,4 do
                GlobalsSetValue( pen.GLOBAL_JPAD_ZONE..i, pen.t.pack({ frame_num + 3, pic_x, pic_y, zone_w, zone_h }))
            end

            local func = step.func or guide[ module_id ].func
            if( func ~= nil ) then
                is_done = func( pic_x, pic_y, zone_w, zone_h,
                    screen_x, screen_y, alpha, fog, is_done, guide[ module_id ], step )
            else
                fog( pic_x, pic_y, zone_w, zone_h, screen_x, screen_y, alpha, step.fog or guide[ module_id ].fog )

                local title_x = screen_x/2
                local title = "TUTORIAL - "..pen.magic_translate( guide[ module_id ].name )
                if( pic_x + zone_w < screen_x*0.66 and pic_x + zone_w > screen_x*0.33 and pic_y < 15 ) then
                    title_x = pen.get_text_dims( title, true )/2 + 5
                end

                pen.new.text_shad( pen.estimate( "vector_tutorial_t", { title_x, -100 }, "wgt0.5" ), 5,
                    pen.Z.TUTORIAL_TIPS, title, { color = pen.P.HRMS.BLUE_3, is_centered_x = true, alpha = alpha })
                
                local is_top = false
                local name = "{>color>{{-}|HRMS|GREY_5|{-}"..pen.magic_translate( step.name ).."}<color<}"
                local desc = name.."\n"..pen.magic_translate( step.desc )
                local desc_w, desc_h = unpack( pen.get_tip_dims( desc, math.max( zone_w, 150 ), -1, -2 ))
                local text_anim = pen.estimate( "vector_tutorial_o", { 0, 2*screen_x }, "wgt0.4" )
                local t_x, t_y = pic_x + ( pic_x < screen_x/2 and -1 or 1 )*text_anim + 2, pic_y + zone_h + 2
                if( pic_x + desc_w + 4 > screen_x ) then t_x = t_x - ( pic_x + desc_w + 4 - screen_x ) end
                if( t_y + desc_h + 9 > screen_y ) then is_top, t_y = true, pic_y - desc_h - 4 end
                pen.new.text_shad( t_x, t_y, pen.Z.TUTORIAL_TIPS, desc, {
                    dims = { desc_w + 2, -1 }, fully_featured = true, line_offset = -2, alpha = alpha })
                
                local function new_button( pic_x, pic_y, pic_z, pic, data )
                    data = data or {}
                    data.ignore_multihover = false
                    data.frames = data.frames or 20
                    data.highlight = data.highlight or pen.P.HRMS.RED_2
                
                    data.lmb_event = data.lmb_event or function( pic_x, pic_y, pic_z, pic, d )
                        if( not( d.no_anim )) then pen.atm( d.auid.."l", nil, true ) end
                        return pic_x, pic_y, pic_z, pic, d
                    end
                    data.rmb_event = data.rmb_event or function( pic_x, pic_y, pic_z, pic, d )
                        if( not( d.no_anim )) then pen.atm( d.auid.."r", nil, true ) end
                        return pic_x, pic_y, pic_z, pic, d
                    end
                    data.hov_event = data.hov_event or function( pic_x, pic_y, pic_z, pic, d )
                        if( pen.vld( d.highlight )) then pen.new.pixel(
                            pic_x - 1, pic_y - 1, pic_z + 0.01, d.highlight,
                            ( d.s_x or 1 )*d.dims[1] + 2, ( d.s_y or 1 )*d.dims[2] + 2 ) end
                        return pic_x, pic_y, pic_z, pic, d
                    end
                
                    return pen.new.button( pic_x, pic_y, pic_z, pic, data )
                end

                mnee.ignore_zone_mode = true

                local is_first = ( progress_local[ module_id ] or 1 ) == 1
                local btn_x, btn_y = pic_x + zone_w + 2, pic_y + zone_h - 12
                if( btn_x + 25 > screen_x ) then btn_x = pic_x - 24 end
                if( is_top ) then btn_y = pic_y + 2 end
                
                local go_back = new_button( btn_x, btn_y, pen.Z.TUTORIAL_TIPS,
                    "mods/vector_core/back"..( is_first and "_" or "" )..".png", { auid = "vector_tutorial_back", jpad = true })
                if( go_back and not( is_first )) then
                    pen.play_sound( pen.S.VNL.SELECT )
                    pen.c.estimator_memo[ "vector_tutorial_o" ] = nil
                    progress_local[ module_id ] = math.max(( progress_local[ module_id ] or 1 ) - 1, 1 )
                    GlobalsSetValue( global_tutorial_progress, pen.t.pack( pen.t.unarray( progress_local )))
                end

                if( is_done ) then
                    local frame_sin = 100*( math.sin( frame_num/10 ) + 1 )
                    pen.colourer( pen.new.builder(), { 255, 255 - frame_sin/4, 255 - frame_sin }) 
                end
                is_done = new_button( btn_x + 12, btn_y, pen.Z.TUTORIAL_TIPS,
                    "mods/vector_core/next.png", { auid = "vector_tutorial_next", jpad = true })
                if( is_done ) then
                    pen.play_sound( pen.S.VNL.CLICK )
                    pen.c.estimator_memo[ "vector_tutorial_o" ] = nil
                end

                mnee.ignore_zone_mode = nil
            end
        end
        
        if( not( is_done )) then return end
        progress_local[ module_id ] = ( progress_local[ module_id ] or 1 ) + 1
        GlobalsSetValue( global_tutorial_progress, pen.t.pack( pen.t.unarray( progress_local )))

        if( will_save ) then
            progress_global = pen.t.unarray( progress_global )
            if( progress_local[ module_id ] <= ( progress_global[ module_id ] or 0 )) then return end
            progress_global[ module_id ] = progress_local[ module_id ]
            pen.setting_set( setting_tutorial_progress, pen.t.pack( pen.t.unarray( progress_global )))
        end
    end

    vector_effect() -- timed effects within unified context

    pen.t.loop( EntityGetWithTag( "vector_ctrl" ), function( i, entity_id )
        pen.t.loop({
            { "vector_stress", vector_stress }, -- adrenaline system
            { "vector_handling", vector_handling }, -- advanced wand handling
            { "vector_controls", vector_controls }, -- M-Nee based controls
            { "vector_momentum", vector_momentum }, -- momentum-based speed controller
        }, function( i, module )
            local name = module[1]
            if( name == "vector_controls" ) then pen.c.vector_cntrls[ entity_id ] = false end
            
            local func, funcs_pre, funcs_post = module[2], nil, nil
            local path_total = pen.magic_storage( entity_id, name.."_total", "value_string" )
            if( pen.vld( path_total )) then func = dofile( path_total ) end
            local path_pre = pen.magic_storage( entity_id, name.."_pre", "value_string" )
            if( pen.vld( path_pre )) then funcs_pre = pen.t.pack( path_pre ) end
            local path_post = pen.magic_storage( entity_id, name.."_post", "value_string" )
            if( pen.vld( path_post )) then funcs_post = pen.t.pack( path_post ) end
            
            func( entity_id, funcs_pre, funcs_post )
        end)

        vector_ctrl( entity_id ) -- entity scripts within unified context
    end)

    vector_tutorial() -- centralized tutorial framework

	pen.new.builder( true )
end

function OnWorldPostUpdate()
    dofile_once( "mods/mnee/lib.lua" )

    pen.c.vector_a_memo = pen.c.vector_a_memo or {}
    pen.c.vector_last_e = pen.c.vector_last_e or {}
    pen.c.vector_acount = pen.c.vector_acount or {}
    pen.c.vector_aimdlt = pen.c.vector_aimdlt or {}
    pen.c.vector_aimzom = pen.c.vector_aimzom or {}

    local function vector_anim( entity_id )
        -- Rib's char animation concept, make sure stains work with it
        -- check whether stains do need a comp per spritecomp or if it works as is
        -- should also include fully procedural animation system (manipulates child objects tagged as limbs)
    end

    --one frame delay is from SpriteComp being updated by the engine
    local function vector_anim_events( entity_id )
        if( pen.magic_storage( entity_id, "vector_no_events", "value_bool" )) then return end
        if( not( pen.vld( pen.lib.nxml ))) then return end
        
        local anim_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "SpriteAnimatorComponent" )
        if( not( pen.vld( anim_comp, true ))) then return end
        local pic_name = ComponentGetValue2( anim_comp, "target_sprite_comp_name" )
        local pic_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "SpriteComponent", pic_name )
        if( not( pen.vld( pic_comp, true ))) then return end

        pen.c.vector_a_memo[ entity_id ] = pen.c.vector_a_memo[ entity_id ] or {}

        local memo = pen.c.vector_a_memo[ entity_id ]
        local pic = ComponentGetValue2( pic_comp, "image_file" )
        local anim_name = ComponentGetValue2( pic_comp, "rect_animation" )
        if( pen.vld( anim_name )) then
            local is_new = memo[1] ~= anim_name
            if( is_new ) then pen.c.vector_acount[ entity_id ] = 0 end
            pen.c.vector_a_memo[ entity_id ][1] = anim_name
        end

        local cnt = pen.c.vector_acount[ entity_id ] or 0
        local length, no_loop = memo[2] or ( cnt + 1 ), memo[3] or false

        local xml = pen.lib.nxml.parse( pen.magic_read( pic ))
        local event = pen.t.loop( xml:all_of( "RectAnimation" ), function( i,v )
            if( v.attr.name ~= anim_name ) then return end
            local delay = 60*v.attr.frame_wait
            length = delay*v.attr.frame_count
            pen.c.vector_a_memo[ entity_id ][2] = length
            no_loop = v.attr.loop == "0"
            pen.c.vector_a_memo[ entity_id ][3] = no_loop
            
            local frame = math.floor( cnt/delay )
            local is_going = ( frame + 2 ) < tonumber( v.attr.frame_count )
            return pen.t.loop( v.children, function( e,c )
                local on_chance = math.random() <= tonumber( c.attr.probably or 1 )
                local on_finished = ( c.attr.on_finished == "1" ) and not( is_going )
                local on_frame = ( c.attr.on_finished ~= "1" ) and ( frame == tonumber( c.attr.frame ))
                if( on_chance and ( on_frame or on_finished )) then return c.attr.name end
            end)
        end)
        
        if( cnt < length ) then cnt = cnt + 1; pen.c.vector_acount[ entity_id ] = cnt end
        if( cnt >= length ) then pen.c.vector_acount[ entity_id ] = no_loop and length or 0 end
        pen.magic_storage( entity_id, "vector_anim_event", "value_string", event or "" )
        
        if( not( pen.vld( event ))) then pen.c.vector_last_e[ entity_id ] = event end
        if( pen.c.vector_last_e[ entity_id ] == event ) then return end
        pen.c.vector_last_e[ entity_id ] = event

        pen.magic_storage( entity_id, "vector_anim_event_frame", "value_int", GameGetFrameNum() + 1 )
    end

    --try moving it to preupdate if force overriding the cam pos is impossible with this system
    local function vector_camera( entity_id, injections_pre, injections_post )
        if( pen.magic_storage( entity_id, "vector_no_camera", "value_bool" )) then return end
        local plat_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "PlatformShooterPlayerComponent" )
        if( not( pen.vld( plat_comp, true ))) then return end
        local ctrl_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "ControlsComponent" )
        if( not( pen.vld( ctrl_comp, true ))) then return end
        ComponentSetValue2( plat_comp, "center_camera_on_this_entity", false )

        local jpad = pen.magic_storage( entity_id, "vector_jpad", "value_int" ) or 0

        local _m_x, _m_y = pen.get_mouse_pos( true, jpad )
        local x, y = EntityGetTransform( entity_id )

        local d_x, d_y = _m_x - x, _m_y - y
        local d_r = math.atan2( d_y, d_x )
        local d_l = math.sqrt( d_x^2 + d_y^2 )
        
        local m_x, m_y = pen.get_mouse_pos( false, jpad )
        local s_x, s_y = pen.get_screen_data()
        s_x, s_y = s_x/2, s_y/2

        local is_looking = pen.c.vector_aimzom[ entity_id ]
        local is_guied = GlobalsGetValue( pen.GLOBAL_JPAD_FOCUS..jpad, "" ) ~= ""
        local edge, is_in = is_looking and 100 or 30, pen.is_inv_active() or is_guied
        local is_out = (( m_x - s_x )/( s_x - edge ))^2 + (( m_y - s_y )/( s_y - edge ))^2 > 1
        if( not( is_out )) then pen.c.vector_aimzom[ entity_id ] = false end
        is_in = is_in or ( GameGetFrameNum() - tonumber( GlobalsGetValue( pen.GLOBAL_INPUT_FRAME, "0" )) < 2 )

        pen.t.loop( injections_pre, function( i, injection )
            if( not( ModDoesFileExist( injection ))) then return end
            d_r, d_l = dofile( injection )( entity_id, d_r, d_l )
        end)

        if( not( is_in ) and is_out and not( is_looking )) then
            local md_x, md_y = ComponentGetValue2( ctrl_comp, "mMouseDelta" )
            local is_holding = math.sqrt( md_x^2 + md_y^2 ) < 10
            local hold_frames = is_holding and pen.c.vector_aimdlt[ entity_id ] or 0
            
            is_out = hold_frames > 20
            pen.c.vector_aimzom[ entity_id ] = is_out
            pen.c.vector_aimdlt[ entity_id ] = hold_frames + 1
        else pen.c.vector_aimdlt[ entity_id ] = 0 end

        local off_x = tonumber( MagicNumbersGetValue( "VIRTUAL_RESOLUTION_X" ))
        local off_y = tonumber( MagicNumbersGetValue( "VIRTUAL_RESOLUTION_Y" ))
        if( is_in ) then d_l = d_l/25 elseif( is_out ) then d_l = off_x/3 + d_l/10 else d_l, speed = d_l/4, 20 end

        local ratio = is_looking and off_y/off_x or 1
        local c_x = pen.estimate( "vector_cam_x_"..entity_id, x + d_l*math.cos( d_r ), "wgt0.1" )
        local c_y = pen.estimate( "vector_cam_y_"..entity_id, y + ratio*d_l*math.sin( d_r ), "wgt0.1" )

        --do straightforward split-screen system
        local is_right = false--GameGetFrameNum()%2 == 1
        -- local color = 255*pen.new.slider( "test1", 50, 50, pen.Z.TIPS, 100 )/100
        -- local correction = pen.new.slider( "test2", 50, 75, pen.Z.TIPS, 100 )/100
        -- pen.new.pixel( is_right and s_x or -5, -5, pen.Z.WORLD_UI - 100, color, s_x + 5, 2*s_y + 10 )
        -- pen.new.pixel( is_right and -5 or s_x, -5, pen.Z.WORLD_UI - 100, color, s_x + 5, 2*s_y + 10, correction )
        local c_x = c_x - ( is_right and 500 or 0 )

        pen.t.loop( injections_post, function( i, injection )
            if( not( ModDoesFileExist( injection ))) then return end
            c_x, c_y = dofile( injection )( entity_id, c_x, c_y )
        end)

        ComponentSetValueVector2( plat_comp, "mDesiredCameraPos", c_x, c_y )
    end

    pen.t.loop( EntityGetWithTag( "vector_ctrl" ), function( i, entity_id )
        vector_anim( entity_id ) -- layered animation controller
        vector_anim_events( entity_id ) -- animation-based events

        pen.t.loop({
            { "vector_camera", vector_camera }, -- responsive camera controller
        }, function( i, module )
            local name = module[1]
            local func, funcs_pre, funcs_post = module[2], nil, nil
            local path_total = pen.magic_storage( entity_id, name.."_total", "value_string" )
            if( pen.vld( path_total )) then func = dofile( path_total ) end
            local path_pre = pen.magic_storage( entity_id, name.."_pre", "value_string" )
            if( pen.vld( path_pre )) then funcs_pre = pen.t.pack( path_pre ) end
            local path_post = pen.magic_storage( entity_id, name.."_post", "value_string" )
            if( pen.vld( path_post )) then funcs_post = pen.t.pack( path_post ) end
            
            func( entity_id, funcs_pre, funcs_post )
        end)
    end)
end

function OnPlayerSpawned( hooman ) --repackage this as a part of Noita Overhaul
    -- EntityAddTag( hooman, "vector_ctrl" )
end