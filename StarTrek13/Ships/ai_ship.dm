#define SIMPLIFY_DEGREES(degrees) (MODULUS((degrees), 360))
#define TO_DEGREES(radians) ((radians) * 57.2957795)

/obj/structure/overmap/ship/AI
	name = "Rogue Omega Class Destroyer"
	icon = 'StarTrek13/icons/trek/large_ships/hyperion.dmi'
	icon_state = "hyperion"
//	pixel_x = -100
//	pixel_y = -100
//	var/datum/shipsystem_controller/SC
	warp_capable = TRUE
	max_warp = 2
	max_health = 20000
	pixel_z = -128
	pixel_w = -120
	var/obj/structure/overmap/stored_target
	var/obj/structure/overmap/force_target //Forced to attack another overmap by a player. HUNT IT DOWN UNTIL IT'S DEAD
	max_speed = 1
	acceleration = 0.1
	damage = 5000
//	spawn_name = "ai_spawn"
	var/firecost = 1000 // Buffs AI ships
	var/dam = 3500 //They always hit quite hard, this is to prevent negative numbers
	var/chargerate = 500
	var/maxcharge = 6000
	faction = "pirate"
	spawn_random = FALSE
	var/turf/rally_point //Are we being told to move to a rally point?
	respawn = FALSE
	var/aggressive = TRUE
	random_name = FALSE
	inherit_name_from_area = FALSE
	var/mob/camera/aiEye/remote/rts/RTSeye //used to relay combat sounds


/* COMMAND PRIORITY:

	: Check for force target / what we're ordered to attack :
	: Check if there's a rally point :
	: If no to both, attack our stored_target which is one we chose at random:

*/

/obj/structure/overmap/ship/AI/Initialize(timeofday)
	. = ..()
	name = true_name
	overmap_objects += src
	START_PROCESSING(SSobj,src)
	linkto()
	if(spawn_random)
		var/list/thelist = list()
		for(var/obj/effect/landmark/A in GLOB.landmarks_list)
			if(A.name == spawn_name)
				thelist += A
				continue
		if(thelist.len)
			var/obj/effect/landmark/A = pick(thelist)
			var/turf/theloc = get_turf(A)
			if(spawn_random)
				forceMove(theloc)
	check_overlays()
	SC.shields.toggled = TRUE
	SC.shields.power = 90000000000 //IT'S OVER 9000000
	SC.shields.power_supplied = 2


/obj/structure/overmap/ship/AI/New()
	. = ..()
	name = "[name] ([rand(0,1000)])"
	while(1)
		stoplag()
		ProcessMove()
		EditAngle()
		TurnTo()
		if(!stored_target in orange(src, 6))
			stored_target = null

/obj/structure/overmap/ship/AI/linkto()	//weapons etc. don't link!
	for(var/area/AR in world)
		if(istype(AR, /area/ship/ai))
			linked_ship = AR
			return

/obj/structure/overmap/ship/AI/process()
	. = ..()
	if(force_target)
		if(stored_target in orange(src, 15))
			if(prob(60)) //Allow it time to recharge
				fire(force_target)
	if(!stored_target || !force_target || !rally_point)
		aggressive = TRUE //Alright no target, back to autotarget
		PickRandomShip()
		if(current_beam)
			qdel(current_beam)
	if(stored_target in orange(src, 15))
		if(prob(60)) //Allow it time to recharge
			fire(stored_target)
	else
		stored_target = null
	if(vel < max_speed)
		vel += acceleration
	SC.engines.charge += 500 //So theyre able to warp

/obj/structure/overmap/ship/AI/take_damage()
	if(agressor)
		stored_target = agressor
	if(RTSeye)
		var/sound/S = pick(ship_damage_sounds)
		if(RTSeye.console && RTSeye.console.operator)
			RTSeye.play_voice(S)
	. = ..()


/obj/structure/overmap/ship/AI/proc/PickRandomShip()
	if(agressor)
		stored_target = agressor
	if(!aggressive) //Do we attack on sight?
		return
	if(!stored_target)
		for(var/obj/structure/overmap/S in orange(src, 15))
			if(istype(S, /obj/structure/overmap)&& !istype(S, /obj/structure/overmap/shipwreck) && !istype(S, /obj/structure/overmap/planet) && !istype(S, /obj/structure/overmap/away/station/system_outpost)) //Don't blow up crucial game things
				if(S.faction == faction) //allows for teams of ships
					continue
				if(!S.cloaked)
					stored_target = S
					break
		return

/obj/structure/overmap/ship/AI/fire(obj/structure/overmap/target) //Try to get a lock on them, the more they move, the harder this is.
	if(wrecked)
		return 0
	if(target)
		if(istype(target, /obj/structure/overmap))
			target.agressor = src
	attempt_fire() //Time to fire then
	return

/obj/structure/overmap/ship/AI/attempt_fire()
	if(wrecked)
		return
	var/obj/structure/overmap/S = null
	if(force_target)
		force_target.agressor = src
		S = force_target
	if(stored_target && !S) //No force target? Okay well did we pick one at random, then?
		stored_target.agressor = src
		S = stored_target
	if(S && S in orange(src, 6))
		if(SC.weapons.attempt_fire())
			SC.weapons.damage = damage
			S.take_damage(SC.weapons.damage,1)
			var/source = get_turf(src)
			SC.weapons.charge -= SC.weapons.fire_cost
			if(current_beam)
				qdel(current_beam)
			current_beam = new(source,get_turf(S),time=500,beam_icon_state="phaserbeam",maxdistance=5000,btype=/obj/effect/ebeam/phaser)
			var/sound/thesound = pick(soundlist)
			if(S.pilot)
				SEND_SOUND(S.pilot, thesound)
			if(RTSeye)
				if(RTSeye.console && RTSeye.console.operator)
					RTSeye.play_voice(thesound)
			spawn(0)
			current_beam.Start()
			return

/obj/structure/overmap/ship/AI/TurnTo(atom/target)
	if(force_target)
		if(force_target in orange(src, 5))
			vel = 0
			target = force_target
			var/obj/structure/overmap/ship/self = src //I'm a reel cumputer syentist :)
			EditAngle()
			angle = 450 - SIMPLIFY_DEGREES(ATAN2((32*target.y+target.pixel_y) - (32*self.y+self.pixel_y), (32*target.x+target.pixel_x) - (32*self.x+self.pixel_x)))
			return
		else
			target = force_target
			var/obj/structure/overmap/ship/self = src //I'm a reel cumputer syentist :)
			EditAngle()
			angle = 450 - SIMPLIFY_DEGREES(ATAN2((32*target.y+target.pixel_y) - (32*self.y+self.pixel_y), (32*target.x+target.pixel_x) - (32*self.x+self.pixel_x)))
			return
	if(rally_point)
		move_to_rally()
		return
	target = stored_target
	if(stored_target in orange(src, 2))
		vel = 0
		return
	if(target)
		var/obj/structure/overmap/ship/self = src //I'm a reel cumputer syentist :)
		EditAngle()
		angle = 450 - SIMPLIFY_DEGREES(ATAN2((32*target.y+target.pixel_y) - (32*self.y+self.pixel_y), (32*target.x+target.pixel_x) - (32*self.x+self.pixel_x)))

/obj/structure/overmap/ship/AI/proc/move_to_rally()
	if(!rally_point in get_area(src))
		rally_point = null
		return
	if(rally_point)
		if(rally_point in orange(src, 2))
			vel = 0
			on_reach_rally()
			return
		else
			var/obj/structure/overmap/ship/self = src //I'm a reel cumputer syentist :)
			EditAngle()
			angle = 450 - SIMPLIFY_DEGREES(ATAN2((32*rally_point.y+rally_point.pixel_y) - (32*self.y+self.pixel_y), (32*rally_point.x+rally_point.pixel_x) - (32*self.x+self.pixel_x)))

/obj/structure/overmap/ship/AI/proc/on_reach_rally()
	return //Mainly used for constructor ships

/obj/structure/overmap/proc/Orbit(atom/target)
	var/obj/structure/overmap/ship/self = src //I'm a reel cumputer syentist :)
	EditAngle()
	angle = 360 - SIMPLIFY_DEGREES(ATAN2((32*target.y+target.pixel_y) - (32*self.y+self.pixel_y), (32*target.x+target.pixel_x) - (32*self.x+self.pixel_x)))


/obj/structure/overmap/ship/AI/small
	name = "Pirate Reaver"
	icon = 'StarTrek13/icons/trek/overmap_ships.dmi'
	icon_state = "pirateship"
	max_health = 8000
	max_speed = 2
	acceleration = 0.5
	faction = "pirate"

/obj/structure/overmap/ship/AI/wars
	name = "Blockade runner"
	icon = 'StarTrek13/icons/trek/large_ships/tantive_iv.dmi'
	icon_state = "corvette"
	max_health = 25000
	max_speed = 2
	acceleration = 0.3
	faction = "pirate"

/area/ship/ai
	name = "Uss AI ship"

/area/ship/ai/two
	name = "Uss AI ship 2: Electric boogaloo"
