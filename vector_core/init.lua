if( ModIsEnabled( "mnee" )) then
	ModLuaFileAppend( "mods/mnee/bindings.lua", "mods/vector_core/mnee.lua" )
else return end

function OnWorldPreUpdate()
    dofile_once( "mods/mnee/lib.lua" )

    local global_top_speed = "VECTOR_TOP_CHAR_SPEED"
    local global_bottom_speed = "VECTOR_BOTTOM_CHAR_SPEED"
    local global_friction = "VECTOR_BASELINE_FRICTION"
    local flag_second_life = "VECTOR_DAMAGE_PREVENTION_SAFETY"
    if( GameHasFlagRun( flag_second_life )) then GameRemoveFlagRun( flag_second_life ) end

    pen.c.vector_recoil = pen.c.vector_recoil or {}
    pen.c.vector_v_memo = pen.c.vector_v_memo or {}
    pen.c.vector_acount = pen.c.vector_acount or {}
    pen.c.vector_a_memo = pen.c.vector_a_memo or {}

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
                ComponentSetValue2( ctrl_comp, "mButtonFrame"..name, frame_num ) end
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

        update_key( "fire", "Fire", "guied" ) --mButtonLastFrameFire
        update_key( "fire_alt", "Fire2", "guied" )

        local will_change_r = update_key( "next_item", "ChangeItemR" )
        ComponentSetValue2( ctrl_comp, "mButtonCountChangeItemR", pen.b2n( will_change_r ))
        local will_change_l = update_key( "last_item", "ChangeItemL" )
        ComponentSetValue2( ctrl_comp, "mButtonCountChangeItemL", pen.b2n( will_change_l ))
        
        update_key( mnee.mnin( "key", "mouse_left", { mode = "guied" }), "LeftClick" )
        update_key( mnee.mnin( "key", "mouse_right", { mode = "guied" }), "RightClick" )

        -- mAimingVector
        -- mAimingVectorNormalized
        -- mMousePosition
        -- mMousePositionRaw
        -- mMousePositionRawPrev
        -- mMouseDelta
    end

    local function vector_recoil( entity_id )
        pen.c.vector_recoil[ entity_id ] = 0

        if( pen.magic_storage( entity_id, "vector_no_recoil", "value_bool" )) then return end

        local gun_id = pen.get_active_item( entity_id )
        if( not( pen.vld( gun_id, true ))) then return end
        local arm_id = pen.get_child( entity_id, "arm_r" )
        if( not( pen.vld( arm_id, true ))) then return end
        local abil_comp = EntityGetFirstComponentIncludingDisabled( gun_id, "AbilityComponent" )
        if( not( pen.vld( abil_comp, true ))) then return end
        local char_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "CharacterDataComponent" )
        if( not( pen.vld( char_comp, true ))) then return end

        -- params are determined by gun and player stats
        local eid_x = arm_id.."x"
        local ix = pen.estimate( eid_x, 0, "exp5" )
        local eid_y = arm_id.."y"
        local iy = pen.estimate( eid_y, 0, "exp5" )
        local eid_r = arm_id.."r"
        local r = pen.estimate( eid_r, 0, "exp5" )

        local trans_comp = EntityGetFirstComponentIncludingDisabled( arm_id, "InheritTransformComponent" )
        local _, _, isx, isy, ir = ComponentGetValue2( trans_comp, "Transform" )

        ComponentSetValue2( trans_comp, "only_position", false )
        ComponentSetValue2( trans_comp, "Transform", ix, iy, isx, isy, ir )
        ComponentSetValue2( abil_comp, "item_recoil_rotation_coeff", r )
        
        if( ComponentGetValue2( abil_comp, "mItemRecoil" ) ~= 1 ) then return end

        -- local v_x, v_y = ComponentGetValue2( char_comp, "mVelocity" )
        -- local prev_x, prev_y = unpack( pen.c.vector_v_memo[ entity_id ] or { v_x, v_y })
        -- ComponentSetValue2( char_comp, "mVelocity", prev_x, v_y )
        -- pen.c.vector_recoil[ entity_id ] = v_x - prev_x

        --recoil always applies first to the arm; above certain limit it pushes the player too; even higher values deal damage
        --tilting should be determined by strength (derived from kick damage), the higher the strength, the less is the shifting amount

        local recoil_storage = pen.magic_storage( gun_id, "recoil" )
        if( not( pen.vld( recoil_storage, true ))) then return end
        local recoil = ComponentGetValue2( recoil_storage, "value_float" )
        pen.c.estimator_memo[ eid_x ] = pen.c.estimator_memo[ eid_x ] - recoil
        pen.c.estimator_memo[ eid_y ] = pen.c.estimator_memo[ eid_y ] - recoil
        pen.c.estimator_memo[ eid_r ] = pen.c.estimator_memo[ eid_r ] + 5*recoil
        ComponentSetValue2( recoil_storage, "value_float", 0 )
    end
    
    local function vector_momentum( entity_id )
        if( pen.magic_storage( entity_id, "vector_no_momentum", "value_bool" )) then return end
        local char_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "CharacterDataComponent" )
        if( not( pen.vld( char_comp, true ))) then return end
        local plat_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "CharacterPlatformingComponent" )
        if( not( pen.vld( plat_comp, true ))) then return end
        local ctrl_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "ControlsComponent" )
        if( not( pen.vld( ctrl_comp, true ))) then return end
        
        local x, y = EntityGetTransform( entity_id )
        local near_ground = RaytracePlatforms( x, y, x, y + 5 )
        local is_ground = ComponentGetValue2( char_comp, "is_on_ground" )
        local is_wall = ComponentGetValue2( char_comp, "mCollidedHorizontally" )

        local jump = ComponentGetValue2( ctrl_comp, "mButtonDownJump" )
        local gravity = ComponentGetValue2( plat_comp, "pixel_gravity" )/60
        local y_transfer = is_wall and near_ground and jump
        
        --do water drag manually
        local v_x, v_y = ComponentGetValue2( char_comp, "mVelocity" )
        v_x = is_wall and 0.75*(( pen.c.vector_v_memo[ entity_id ] or {})[1] or 0 ) or v_x
        v_y = y_transfer and v_y - ( gravity/2 + math.max( 50, math.abs( v_x ))) or v_y
        v_x = v_x + ( pen.c.vector_recoil[ entity_id ] or 0 )
        
        local strength = 0
        local kick_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "KickComponent" )
        if( pen.vld( kick_comp, true )) then strength = 3*ComponentGetValue2( kick_comp, "max_force" ) end
        if( not( ComponentGetValue2( char_comp, "is_on_ground" ))) then strength = 0 end
        local plat_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "CharacterDataComponent" )
        if( pen.vld( plat_comp, true ) and ComponentGetValue2( plat_comp, "mJetpackEmitting" )) then
            strength = ComponentGetValue2( plat_comp, "fly_velocity_x" )
        end

        local mass = pen.get_full_mass( entity_id ) --default is 1 which is considered 40kg
        mass = ( ComponentGetValue2( char_comp, "is_on_slippery_ground" ) and 2 or 1 )*mass
        local top_speed = tonumber( GlobalsGetValue( global_top_speed, "200" ))
        local bottom_speed = tonumber( GlobalsGetValue( global_bottom_speed, "20" ))

        local left = ComponentGetValue2( ctrl_comp, "mButtonDownLeft" )
        local right = ComponentGetValue2( ctrl_comp, "mButtonDownRight" )
        if( left or right ) then
            local force = strength*pen.get_ratio( v_x, top_speed )*pen.get_ratio( mass, strength )
            v_x = v_x + force*( right and 1 or -1 )
        end

        local decay = tonumber( GlobalsGetValue( global_friction, "0.99" ))
        if( is_ground ) then
            local old_sign, k = pen.get_sign( v_x ), 10
            if( math.abs( v_x ) < bottom_speed ) then k = k*pen.get_ratio( v_x, 2*bottom_speed ) end
            v_x = v_x - k*pen.get_sign( v_x )*math.abs( decay )*pen.get_ratio( mass, strength )
            if( old_sign ~= pen.get_sign( v_x )) then v_x = 0 end
        else v_x = decay*v_x end

        ComponentSetValue2( char_comp, "mVelocity", v_x, v_y )
        pen.c.vector_v_memo[ entity_id ] = { v_x, v_y }
    end

    --events are only reported once per unique frame
    local function vector_anim_events( entity_id )
        if( pen.magic_storage( entity_id, "vector_no_events", "value_bool" )) then return end
        if( not( ModIsEnabled( "penman" ))) then return end
        dofile_once( "mods/penman/_libman.lua" )

        local anim_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "SpriteAnimatorComponent" )
        if( not( pen.vld( anim_comp, true ))) then return end
        local pic_name = ComponentGetValue2( anim_comp, "target_sprite_comp_name" )
        local pic_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "SpriteComponent", pic_name )
        if( not( pen.vld( pic_comp, true ))) then return end

        local pic = ComponentGetValue2( pic_comp, "image_file" )
        local anim_name = ComponentGetValue2( pic_comp, "rect_animation" )
        local is_new = pen.c.vector_a_memo[ entity_id ] ~= anim_name
        if( is_new ) then pen.c.vector_acount[ entity_id ] = 0 end
        pen.c.vector_a_memo[ entity_id ] = anim_name

        local cnt = pen.c.vector_acount[ entity_id ] or 0
        local length = cnt + 1

        local xml = pen.lib.nxml.parse( pen.magic_read( pic ))
        local event = pen.t.loop( xml:all_of( "RectAnimation" ), function( i,v )
            if( v.attr.name ~= anim_name ) then return end
            local delay = 60*v.attr.frame_wait
            length = delay*v.attr.frame_count
            
            local frame = math.floor( cnt/delay )
            local is_going = ( frame + 2 ) < tonumber( v.attr.frame_count )
            return pen.t.loop( v.children, function( e,c )
                if( is_going and c.attr.on_finished ) then
                    return
                elseif( frame ~= tonumber( c.attr.frame )) then
                    return
                elseif( math.random() > ( tonumber( c.attr.probably or 1 ))) then
                    return
                end
                
                return c.attr.name
            end)
        end)

        pen.c.vector_acount[ entity_id ] = cnt + 1
        if( cnt > length ) then pen.c.vector_acount[ entity_id ] = 0 end
        pen.magic_storage( entity_id, "vector_anim_event", "value_string", event or "" )
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
        -- vector_controls( entity_id ) -- M-Nee based controls
        vector_recoil( entity_id ) -- advanced wand handling
        vector_momentum( entity_id ) -- custom speed controller
        vector_anim_events( entity_id ) -- animation-based events
        vector_ctrl( entity_id ) -- entity scripts within unified context
    end)
end

function OnPlayerSpawned( hooman )
    EntityAddTag( hooman, "vector_ctrl" )
end