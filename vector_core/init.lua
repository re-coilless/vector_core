if( ModIsEnabled( "mnee" )) then
	ModLuaFileAppend( "mods/mnee/bindings.lua", "mods/vector_core/mnee.lua" )
else return end

function OnWorldPreUpdate()
    dofile_once( "mods/mnee/lib.lua" )

    local global_init_speed = "VECTOR_INIT_CHAR_SPEED"
    local global_top_speed = "VECTOR_TOP_CHAR_SPEED"
    local global_bottom_speed = "VECTOR_BOTTOM_CHAR_SPEED"
    local global_friction = "VECTOR_BASELINE_FRICTION"
    local global_dash_delay = "VECTOR_DASH_DELAY_FRAMES"
    local global_coyote_time = "VECTOR_COYOTE_TIME"
    local flag_second_life = "VECTOR_DAMAGE_PREVENTION_SAFETY"
    if( GameHasFlagRun( flag_second_life )) then GameRemoveFlagRun( flag_second_life ) end

    pen.c.vector_cntrls = pen.c.vector_cntrls or {}
    pen.c.vector_recoil = pen.c.vector_recoil or {}
    pen.c.vector_v_memo = pen.c.vector_v_memo or {}
    pen.c.vector_mnt_mm = pen.c.vector_mnt_mm or {}
    pen.c.vector_coytte = pen.c.vector_coytte or {}
    pen.c.vector_dashmm = pen.c.vector_dashmm or {}
    pen.c.vector_prcisn = pen.c.vector_prcisn or {}
    pen.c.vector_aangle = pen.c.vector_aangle or {}
    pen.c.vector_aasign = pen.c.vector_aasign or {}

    local function vector_stress( entity_id )
        if( pen.magic_storage( entity_id, "vector_no_stress", "value_bool" )) then return end
        local stress = pen.magic_storage( entity_id, "stress", "value_float", nil, 0 )

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
    end
    
    local function vector_handling( entity_id )
        pen.c.vector_recoil[ entity_id ] = { 0, 0 }
        if( pen.magic_storage( entity_id, "vector_no_handling", "value_bool" )) then return end
        local gun_id = pen.get_active_item( entity_id )
        if( not( pen.vld( gun_id, true ))) then return end
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

        if( pen.magic_storage( gun_id, "vector_no_handling", "value_bool" )) then return end

        local aim_x, aim_y = 0, 0
        if( not( pen.c.vector_cntrls[ entity_id ])) then
            local m_x, m_y = DEBUG_GetMouseWorld()
            local arm_x, arm_y = EntityGetTransform( arm_id )
            aim_x, aim_y = m_x - arm_x, m_y - arm_y
        else aim_x, aim_y = ComponentGetValue2( ctrl_comp, "mAimingVector" ) end

        local gun_mass = pen.get_mass( gun_id )
        local strength = pen.get_strength( entity_id )
        local gun_ratio = 100*( pen.get_ratio( gun_mass, strength ) - 0.9 )
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

        local this_angle = math.atan2( aim_y, aim_x )
        local last_angle = pen.c.vector_aangle[ entity_id ] or this_angle
        local this_sign = pen.get_sign( aim_x )
        local sign_flip = this_sign ~= ( pen.c.vector_aasign[ entity_id ] or this_sign )
        local aim_flip = ( h_aim < 0.9 or gun_rating < 0 ) and 0 or 3
        local aim_delta = sign_flip and aim_flip or this_sign*pen.get_angular_delta( this_angle, last_angle )
        local aim_drift = 50*aim_delta*math.min( h_aim, 1 )
        pen.c.vector_aangle[ entity_id ], pen.c.vector_aasign[ entity_id ] = this_angle, this_sign

        --move recoil to the top
        --mass-based momentum for angular recoil
        --make weapon fly away at high recoil
        --two handed weapons (if the gun has front grip hotspot, 1.5*h_aim and 2*h_recoil if it is not enabled)
        --intergrate mnee vector module with firearm handling, so aim actually drifts (use old method if is disabled)

        local eid_x = arm_id.."x"
        local ix = pen.estimate( eid_x, 0, "exp"..arm_speed )
        local eid_y = arm_id.."y"
        local iy = pen.estimate( eid_y, 0, "exp"..arm_speed )
        local eid_r = arm_id.."r"
        pen.c.estimator_memo[ eid_r ] = ( pen.c.estimator_memo[ eid_r ] or 0 ) + aim_drift
        local r = pen.estimate( eid_r, 0, "exp"..hand_speed )

        local trans_comp = EntityGetFirstComponentIncludingDisabled( arm_id, "InheritTransformComponent" )
        local _, _, isx, isy, ir = ComponentGetValue2( trans_comp, "Transform" )

        ComponentSetValue2( trans_comp, "only_position", false )
        ComponentSetValue2( trans_comp, "Transform", ix, iy, isx, isy, ir )
        ComponentSetValue2( abil_comp, "item_recoil_rotation_coeff", r )

        if( ComponentGetValue2( abil_comp, "mItemRecoil" ) ~= 1 ) then
            ComponentSetValue2( abil_comp, "mItemRecoil", 1 )
        end

        local recoil_storage = pen.magic_storage( gun_id, "recoil" )
        if( not( pen.vld( recoil_storage, true ))) then return end
        local recoil = h_recoil*ComponentGetValue2( recoil_storage, "value_float" )
        if( pen.eps_compare( recoil, 0 )) then return end

        local _,_,gun_r = EntityGetTransform( gun_id )
        local x,y,_,s_x = EntityGetTransform( entity_id )
        local tilt = 5*recoil*( 2 - math.min( math.max( 0.1, 100/strength - 0.2 ), 1.9 ))
        pen.c.estimator_memo[ eid_x ] = math.max( pen.c.estimator_memo[ eid_x ] - recoil, -7 )
        pen.c.estimator_memo[ eid_y ] = math.max( pen.c.estimator_memo[ eid_y ] - recoil, -7 )
        pen.c.estimator_memo[ eid_r ] = pen.c.estimator_memo[ eid_r ] + tilt

        local push_force = 10*recoil/pen.get_full_mass( entity_id )
        local no_support = not( ComponentGetValue2( char_comp, "is_on_ground" ))
        if( push_force > 1.5 and no_support ) then push_force = 25*push_force end
        pen.c.vector_recoil[ entity_id ][1] = -push_force*math.cos( gun_r )
        pen.c.vector_recoil[ entity_id ][2] = -push_force*math.sin( gun_r )
        if( push_force > 200 ) then
            --apply stun effect
            EntityInflictDamage( entity_id, push_force/350, "DAMAGE_PHYSICS_HIT", "Could not handle the recoil.", "NORMAL", pen.c.vector_recoil[ entity_id ][1], pen.c.vector_recoil[ entity_id ][2], entity_id, x, y, push_force )
        end

        ComponentSetValue2( recoil_storage, "value_float", 0 )
    end

    --controller support + make it work for any entity + check for game effects
    local function vector_controls( entity_id ) --partially stolen from IotaMP
        if( pen.magic_storage( entity_id, "vector_no_controls", "value_bool" )) then return end
        local ctrl_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "ControlsComponent" )
        if( not( pen.vld( ctrl_comp, true ))) then return end
        ComponentSetValue2( ctrl_comp, "enabled", false )

        local frame_num = GameGetFrameNum()
        local function update_key( mnee_id, name, mode )
            local is_going = mnee_id
            if( type( is_going ) ~= "boolean" ) then
                is_going = mnee.mnin( "bind", { "vector_core", mnee_id }, { dirty = true, mode = mode })
            end
            
            local old_val = ComponentGetValue2( ctrl_comp, "mButtonDown"..name )
            if( is_going and not( old_val )) then
                ComponentSetValue2( ctrl_comp, "mButtonFrame"..name, frame_num + 1 ) end
            ComponentSetValue2( ctrl_comp, "mButtonDown"..name, is_going )
            return is_going
        end

        update_key( "left", "Left" )
        update_key( "right", "Right" )
        update_key( "up", "Up" )
        update_key( "down", "Down" )

        update_key( "run", "Run" )
        update_key( "jump", "Jump" )
        if( update_key( "fly", "Fly" )) then
            local _,new_y = EntityGetTransform( entity_id )
            ComponentSetValue2( ctrl_comp, "mFlyingTargetY", new_y - 10 )
        end

        update_key( "interact", "Interact" )
        update_key( "throw", "Throw" )
        update_key( "kick", "Kick" )

        local shot_main = update_key( "fire", "Fire", "guied" )
        local shot_also = update_key( "fire_alt", "Fire2", "guied" )
        if( shot_main or shot_also ) then
            ComponentSetValue2( ctrl_comp, "mButtonLastFrameFire", frame_num )
        end
        
        update_key( "inventory", "Inventory" )
        if( tonumber( GlobalsGetValue( pen.GLOBAL_UNSCROLLER_SAFETY, "0" )) ~= frame_num ) then
            local will_change_r = update_key( "next_item", "ChangeItemR" )
            ComponentSetValue2( ctrl_comp, "mButtonCountChangeItemR", pen.b2n( will_change_r ))
            local will_change_l = update_key( "last_item", "ChangeItemL" )
            ComponentSetValue2( ctrl_comp, "mButtonCountChangeItemL", pen.b2n( will_change_l ))
        end
        
        update_key( mnee.mnin( "key", "mouse_left", { mode = "guied" }), "LeftClick" )
        update_key( mnee.mnin( "key", "mouse_right", { mode = "guied" }), "RightClick" )

        local ms_x, ms_y = InputGetMousePosOnScreen()
        local _ms_x, _ms_y = ComponentGetValue2( ctrl_comp, "mMousePositionRaw" )
        ComponentSetValue2( ctrl_comp, "mMouseDelta", ms_x - _ms_x, ms_y - _ms_y )
        ComponentSetValue2( ctrl_comp, "mMousePositionRawPrev", _ms_x, _ms_y )
        ComponentSetValue2( ctrl_comp, "mMousePositionRaw", ms_x, ms_y )

        local mw_x, mw_y = DEBUG_GetMouseWorld()
        local x, y = EntityGetTransform( pen.get_child( entity_id, "arm_r" ) or entity_id )
        ComponentSetValue2( ctrl_comp, "mMousePosition", mw_x, mw_y )

        local aim_x, aim_y = mw_x - x, mw_y - y
        local aim = math.atan2( aim_y, aim_x )
        ComponentSetValue2( ctrl_comp, "mAimingVector", aim_x, aim_y )
        ComponentSetValue2( ctrl_comp, "mAimingVectorNormalized", math.cos( aim ), math.sin( aim ))

        pen.c.vector_cntrls[ entity_id ] = true
    end

    local function vector_momentum( entity_id )
        pen.c.vector_recoil[ entity_id ] = pen.c.vector_recoil[ entity_id ] or { 0, 0 }
        if( pen.magic_storage( entity_id, "vector_no_momentum", "value_bool" )) then return end
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
        
        local x, y, _, s_x = EntityGetTransform( entity_id )
        local v_x, v_y = ComponentGetValue2( char_comp, "mVelocity" )
        local gravity = ComponentGetValue2( plat_comp, "pixel_gravity" )/60

        local did_mount = pen.c.vector_mnt_mm[ entity_id ] or false
        local flip = s_x < 0; if( left or right ) then flip = left end
        local head_off = ComponentGetValue2( char_comp, "collision_aabb_min_y" )
        local feet_off = ComponentGetValue2( char_comp, "collision_aabb_max_y" )
        local body_off = ComponentGetValue2( char_comp, "collision_aabb_m"..( flip and "in" or "ax" ).."_x" )
        feet_off, body_off = feet_off - ( did_mount and 0.5 or 3 ), body_off + 2*( flip and -1 or 1 )

        local init_speed = tonumber( GlobalsGetValue( global_init_speed, "7" ))
        local top_speed = tonumber( GlobalsGetValue( global_top_speed, "200" ))
        local bottom_speed = tonumber( GlobalsGetValue( global_bottom_speed, "20" ))
        local dash_delay = tonumber( GlobalsGetValue( global_dash_delay, "5" ))
        local ctime = tonumber( GlobalsGetValue( global_coyote_time, "10" ))
        local decay = tonumber( GlobalsGetValue( global_friction, "0.99" ))

        local near_ground = RaytracePlatforms( x, y, x, y + 5 )
        local is_ground = ComponentGetValue2( char_comp, "is_on_ground" )
        if( is_ground ) then pen.c.vector_coytte[ entity_id ] = frame_num + ctime end
        is_ground = is_ground or (( pen.c.vector_coytte[ entity_id ] or 0 ) > frame_num )
        local is_wall = RaytracePlatforms( x + body_off, y + head_off + 1, x + body_off, y + feet_off )
        is_wall = is_wall or ComponentGetValue2( char_comp, "mCollidedHorizontally" )
        
        --do swimming manually; jumping angle should be based on surface normal and fully procedural
        
        local is_mounting = false
        if((( left and s_x < 0 ) or ( right and s_x > 0 )) and is_wall ) then
            local check_x = x + 2*body_off
            local chest_off = ComponentGetValue2( char_comp, "buoyancy_check_offset_y" )
            local no_space = RaytracePlatforms( check_x, y + chest_off, check_x, y + head_off - 1 )
            no_space = no_space or RaytracePlatforms( check_x, y + head_off - 1, x, y + head_off - 1 )
            is_mounting = not( no_space or RaytracePlatforms( x, y + chest_off, check_x, y + chest_off ))
            if( is_mounting ) then v_y = math.max( -math.max( 7*gravity, math.abs( v_x )), v_y - 3*gravity ) end
        end

        local x_decay = is_wall and not( did_mount )
        local y_transfer = is_wall and near_ground and jump
        v_x = x_decay and 0.9*(( pen.c.vector_v_memo[ entity_id ] or {})[1] or 0 ) or v_x
        v_y = y_transfer and v_y - ( gravity/2 + math.max( 10*gravity, math.abs( v_x ))) or v_y
        v_x, v_y = v_x + ( pen.c.vector_recoil[ entity_id ][1]), v_y + ( pen.c.vector_recoil[ entity_id ][2])
        if( not( is_mounting ) and did_mount ) then v_x = v_x + 50*( flip and -1 or 1 ) end
        pen.c.vector_mnt_mm[ entity_id ] = is_mounting

        local strength = is_ground and pen.get_strength( entity_id ) or 0
        local plat_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "CharacterDataComponent" )
        if( pen.vld( plat_comp, true ) and ComponentGetValue2( plat_comp, "mJetpackEmitting" )) then
            strength = ComponentGetValue2( plat_comp, "fly_velocity_x" )
        end

        local mass = pen.get_full_mass( entity_id ) --default is 1 which is considered 40kg
        mass = ( ComponentGetValue2( char_comp, "is_on_slippery_ground" ) and 2 or 1 )*mass

        --dash is too op, add cooldown or something
        --with this system the bhop momentum seems to decay
        local move_frame = pen.c.vector_dashmm[ entity_id ] or frame_num
        if( left or right ) then
            -- local will_dash = ( move_frame > frame_num ) and ( move_frame - frame_num < dash_delay )
            local force = strength*pen.get_ratio( v_x, top_speed )*pen.get_ratio( mass, strength )
            -- if( will_dash ) then force = 5*force; pen.c.vector_prcisn[ entity_id ] = force end

            -- local prec = math.min( 1.25*( pen.c.vector_prcisn[ entity_id ] or init_speed ), 2*top_speed )
            -- if( is_ground ) then pen.c.vector_dashmm[ entity_id ] = frame_num + dash_delay + 5 end
            v_x = v_x + math.min( force, prec or force )*( right and 1 or -1 )
            -- pen.c.vector_prcisn[ entity_id ] = prec
        elseif( frame_num > move_frame ) then pen.c.vector_prcisn[ entity_id ] = init_speed end
        
        if( is_ground ) then
            local old_sign, k = pen.get_sign( v_x ), 10
            if( math.abs( v_x ) < bottom_speed ) then k = k*pen.get_ratio( v_x, 2*bottom_speed ) end
            v_x = v_x - k*pen.get_sign( v_x )*math.abs( decay )*pen.get_ratio( mass, strength )
            if( old_sign ~= pen.get_sign( v_x )) then v_x = 0 end
        else v_x = decay*v_x end

        ComponentSetValue2( char_comp, "mVelocity", v_x, v_y )
        pen.c.vector_v_memo[ entity_id ] = { v_x, v_y }
        pen.c.vector_recoil[ entity_id ] = { 0, 0 }
    end
    
    local function vector_ctrl( entity_id )
        pen.t.loop( EntityGetComponent( entity_id, "VariableStorageComponent" ), function( i,comp )
            if( ComponentGetValue2( comp, "name" ) ~= "vector_ctrl" ) then return end
            local path = ComponentGetValue2( comp, "value_string" )
            if( not( pen.vld( path ))) then return end
            dofile( path )( entity_id )
        end)
    end

    --allow injecting/overriding functions
    --add vector_ctrl tagged lua script that will restore entity to original state if entity-altering modification are disabled or the main tag is gone
    pen.t.loop( EntityGetWithTag( "vector_ctrl" ), function( i, entity_id )
        pen.c.vector_cntrls[ entity_id ] = false
        vector_stress( entity_id ) -- elaborate adrenaline system
        vector_handling( entity_id ) -- advanced wand handling
        vector_controls( entity_id ) -- M-Nee based controls
        vector_momentum( entity_id ) -- custom speed controller
        vector_ctrl( entity_id ) -- entity scripts within unified context
    end)
end

function OnWorldPostUpdate()
    dofile_once( "mods/mnee/lib.lua" )

    pen.c.vector_a_memo = pen.c.vector_a_memo or {}
    pen.c.vector_last_e = pen.c.vector_last_e or {}
    pen.c.vector_acount = pen.c.vector_acount or {}

    --one frame delay is from SpriteComp being updated by the engine
    local function vector_anim_events( entity_id )
        if( pen.magic_storage( entity_id, "vector_no_events", "value_bool" )) then return end
        if( not( ModIsEnabled( "penman" ))) then return end
        dofile_once( "mods/penman/_libman.lua" )

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

    pen.t.loop( EntityGetWithTag( "vector_ctrl" ), function( i, entity_id )
        vector_anim_events( entity_id ) -- animation-based events
    end)
end

function OnPlayerSpawned( hooman ) --repackage this as a single-line extension for vanilla (name's Noita OVerhaul)
    -- EntityAddTag( hooman, "vector_ctrl" )
end