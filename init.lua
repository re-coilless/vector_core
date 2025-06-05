if( ModIsEnabled( "mnee" )) then
	ModLuaFileAppend( "mods/mnee/bindings.lua", "mods/vector_core/mnee.lua" )
else return end

function OnWorldPreUpdate()
    dofile_once( "mods/mnee/lib.lua" )

    pen.c.vector_moment = pen.c.vector_moment or {}
    pen.c.vector_recoil = pen.c.vector_recoil or {}
    pen.c.vector_v_memo = pen.c.vector_v_memo or {}
    pen.c.vector_acount = pen.c.vector_acount or {}
    pen.c.vector_a_memo = pen.c.vector_a_memo or {}

    --controller support + make it work for any entity
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

        --recoil always applies first to the arm; above certain limit it pushes the player too
        --tilting should be determined by strength (derived from kick damage), the higher the strength, the less is the shifting amount

        local recoil_storage = pen.magic_storage( gun_id, "recoil" )
        if( not( pen.vld( recoil_storage, true ))) then return end
        local recoil = ComponentGetValue2( recoil_storage, "value_float" )
        pen.c.estimator_memo[ eid_x ] = pen.c.estimator_memo[ eid_x ] - recoil
        pen.c.estimator_memo[ eid_y ] = pen.c.estimator_memo[ eid_y ] - recoil
        pen.c.estimator_memo[ eid_r ] = pen.c.estimator_memo[ eid_r ] + 5*recoil
        ComponentSetValue2( recoil_storage, "value_float", 0 )
    end

    --apply clamping
    local function vector_momentum( entity_id )
        if( pen.magic_storage( entity_id, "vector_no_momentum", "value_bool" )) then return end
        local char_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "CharacterDataComponent" )
        if( not( pen.vld( char_comp, true ))) then return end
        
        local new_vel = pen.c.vector_moment[ entity_id ] or 0
        local v_x, v_y = ComponentGetValue2( char_comp, "mVelocity" )
        new_vel = math.abs( new_vel ) < math.abs( v_x ) and v_x or new_vel
        new_vel = new_vel + ( pen.c.vector_recoil[ entity_id ] or 0 )

        local decay = 0.95 --make this increase with higher mass (default is for 80kg)
        if( ComponentGetValue2( char_comp, "is_on_slippery_ground" )) then
            decay = 0.5*decay
        elseif( ComponentGetValue2( char_comp, "is_on_ground" )) then decay = 0.1*decay end
        if( ComponentGetValue2( char_comp, "mCollidedHorizontally" )) then decay = 0 end

        local air_speed = 1
        local plat_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "CharacterDataComponent" )
        if( pen.vld( plat_comp, true ) and ComponentGetValue2( plat_comp, "mJetpackEmitting" )) then air_speed = 5 end
        local ctrl_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "ControlsComponent" )
        if( pen.vld( ctrl_comp, true )) then
            local left = ComponentGetValue2( ctrl_comp, "mButtonDownLeft" )
            local right = ComponentGetValue2( ctrl_comp, "mButtonDownRight" )
            if( left or right ) then new_vel = new_vel + air_speed*( right and 1 or -1 ) end
        end

        ComponentSetValue2( char_comp, "mVelocity", new_vel, v_y )
        pen.c.vector_moment[ entity_id ] = decay*new_vel
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
        local path = pen.magic_storage( entity_id, "vector_ctrl", "value_string" )
        if( not( pen.vld( path ))) then return end
        dofile( path )
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