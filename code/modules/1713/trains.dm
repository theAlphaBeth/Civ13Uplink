/obj/structure/rails
	name = "rails"
	desc = "Rails used by trains."
	icon = 'icons/obj/trains.dmi'
	icon_state = "rails"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	layer = 2.5
	var/switched = "forward"
	var/turn_dir = null
	var/sw_direction = "forward"

/obj/structure/rails/end
	icon_state = "rails_end"


/obj/structure/rails/split
	icon_state = "rails_split"

/obj/structure/rails/turn/right
	icon_state = "rails_turn_right"
	sw_direction = "right"
	New()
		..()
		switch(dir)
			if (1)
				turn_dir = 4
			if (2)
				turn_dir = 8
			if (4)
				turn_dir = 2
			if (8)
				turn_dir = 1

/obj/structure/rails/turn
	icon_state = "rails_turn_left"
	sw_direction = "left"
	New()
		..()
		switch(dir)
			if (1)
				turn_dir = 8
			if (2)
				turn_dir = 4
			if (4)
				turn_dir = 1
			if (8)
				turn_dir = 2

/obj/structure/rails/split/switcher
	icon_state = "rails_split_f_left"
	name = "rail switcher"
	desc = "used to switch between two train tracks. It is set to go forward."
	switched = "forward"
	sw_direction = "left"

/obj/structure/rails/split/switcher/right
	icon_state = "rails_split_f_right"
	name = "rail switcher"
	desc = "used to switch between two train tracks. It is set to go forward."
	switched = "forward"
	sw_direction = "right"

/obj/structure/rails/split/switcher/update_icon()
	if (switched == "forward")
		icon_state = "rails_split_f_[sw_direction]"
	else
		icon_state = "rails_split_s_[sw_direction]"

/obj/structure/rails/rotate
	name = "rotating rail"
	desc = "A rotating platform that allows carriages to switch direction."
	icon_state = "rails_rotate"

/obj/structure/rails/rotate/attack_hand(mob/living/user as mob)
	switch(dir)
		if (1)
			dir = 8
		if (2)
			dir = 4
		if (4)
			dir = 1
		if (8)
			dir = 2
	for (var/obj/structure/trains/TR in loc)
		TR.dir = dir
	playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
	user << "You rotate the platform."
	return
/////////////////////////////////////////////////////////////////////////////////
/obj/structure/train_lever
	name = "rail switch level"
	desc = "A lever used to switch between tracks."
	icon = 'icons/obj/train_lever.dmi'
	icon_state = "lever_none"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	var/switched = "forward"

/obj/structure/train_lever/update_icon()
	if (switched == "forward")
		icon_state = "lever_none"
	else
		icon_state = "lever_pulled"

/obj/structure/train_lever/attack_hand(mob/living/user as mob)
	if (istype(user, /mob/living))
		if (switched == "forward")
			switched = "split"
			for (var/obj/structure/rails/split/switcher/S in range(2,src))
				S.switched = "split"
				S.update_icon()
			visible_message("<span class = 'notice'>[user] moves the lever into the splitting position!</span>", "<span class = 'notice'>You move the lever into the splitting position!</span>")
			playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
			return
		else
			switched = "forward"
			for (var/obj/structure/rails/split/switcher/S in range(2,src))
				S.switched = "forward"
				S.update_icon()
			visible_message("<span class = 'notice'>[user] moves the lever into the forward position!</span>", "<span class = 'notice'>You move the lever into the forward position!</span>")
			update_icon()
			playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
			return

/////////////////////////////////////////////////////////////////////////////////

/obj/structure/trains
	name = "carriage"
	desc = "A carriage meant to be used on rails."
	icon = 'icons/obj/trains.dmi'
	icon_state = "miningcar"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	var/automovement = FALSE
	var/health = 1000
	var/train_speed = 6 //deciseconds of delay, so lower is better
	var/locomotive = FALSE
	var/list/transporting = list()
/obj/structure/trains/Bumped(atom/AM)
	var/turf/tgt = get_step(src,AM.dir)
	if (!tgt)
		return FALSE
	if (isliving(AM))
		var/mob/living/ML = AM
		for (var/obj/structure/trains/TR in AM.loc)
			if (istype(src, /obj/structure/trains/transport))
				ML.forceMove(loc)
				return FALSE
			return FALSE
		if (ML.mob_size < MOB_MEDIUM)
			return FALSE
		for (var/obj/structure/trains/TR in tgt)
			return FALSE
	if (rail_canmove(AM.dir))
		src.Move(tgt, FALSE)
		return TRUE
/obj/structure/trains/Move(var/turf/newloc, var/pullbehind = TRUE)

	if (buckled_mob && map.check_caribbean_block(buckled_mob, newloc))
		return FALSE
	var/turf/behind = get_step(src,OPPOSITE_DIR(dir))
	var/turf/oldloc = loc
	..(newloc)

	if (buckled_mob)
		if (buckled_mob.buckled == src)
			buckled_mob.loc = loc
		else
			buckled_mob = null
	for (var/mob/living/L in oldloc)
		L.loc = loc
	for (var/obj/O in oldloc)
		if (O.anchored && O in transporting)
			O.loc = loc
	if (behind && pullbehind)
		for (var/obj/structure/trains/T in behind)
			if (T.dir == dir)
				T.Move(oldloc)
	for (var/obj/O in transporting)
		if (get_dist(O, src) >= 2)
			transporting -= O
	return TRUE

/obj/structure/trains/proc/rail_movement()
	if (!automovement)
		playsound(src.loc, 'sound/machines/train/stopping.ogg', 100, TRUE)
		return FALSE
	spawn(train_speed)
		if (!automovement)
			playsound(src.loc, 'sound/machines/train/stopping.ogg', 100, TRUE)
			return FALSE
		process_rail_movement()
		rail_movement()
		rail_sound()

/obj/structure/trains/proc/rail_sound()
	if (automovement)
		spawn(10)
			playsound(src.loc, 'sound/machines/train/moving.ogg', 100, TRUE)

/obj/structure/trains/proc/process_rail_movement()
	if (automovement)
		var/turf/tgtt = get_step(src,dir)
		var/turf/curr = get_turf(src)
		if (!curr || !tgtt)
			automovement = FALSE
			return FALSE
		var/obj/structure/rails/RT = null
		for (var/obj/structure/rails/RTT in loc)
			RT = RTT
		if (RT && istype(RT, /obj/structure/rails/split/switcher) && RT.switched == "split" && RT.dir == dir && rail_canmove(dir))
			if (RT.sw_direction == "left")
				switch(RT.dir)
					if (1)
						tgtt = get_step(RT, 8)
					if (2)
						tgtt = get_step(RT, 4)
					if (4)
						tgtt = get_step(RT, 1)
					if (8)
						tgtt = get_step(RT, 2)
			else if (RT.sw_direction == "right")
				switch(RT.dir)
					if (1)
						tgtt = get_step(RT, 4)
					if (2)
						tgtt = get_step(RT, 8)
					if (4)
						tgtt = get_step(RT, 2)
					if (8)
						tgtt = get_step(RT, 1)
		else if (RT && istype(RT, /obj/structure/rails/turn) && RT.turn_dir)
			if (RT.turn_dir == dir)
				dir = RT.dir
				tgtt = get_step(RT, RT.dir)
			else if (RT.dir == dir)
				dir = RT.turn_dir
				tgtt = get_step(RT, RT.turn_dir)
		if (!rail_canmove(dir))
			automovement = FALSE
			return FALSE
		//push (or hit) wtv is in front...
		for (var/obj/structure/trains/TF in tgtt)
			if (TF.rail_canmove(dir))
				TF.dir = dir
				TF.Bumped(src)
			else
				visible_message("\The [src] hits \the [TF]!")
				automovement = FALSE
				health -= 5
				return FALSE
		for (var/obj/O in tgtt)
			if (O.density && !istype(O, /obj/structure/trains) && !istype(O, /obj/structure/rails))
				visible_message("\The [src] hits \the [O]!")
				O.ex_act(1.0)
				health -= 15*O.w_class
				automovement = FALSE
				return FALSE
		for (var/mob/living/L in tgtt)
			var/found = FALSE
			for (var/obj/structure/trains/TT in tgtt)
				found = TRUE
			if (!found)
				if (L.mob_size <= 42)
					visible_message("\The [src] crushes \the [L]!")
					L.crush()
				else
					visible_message("\The [src] hits \the [L]!")
					health -= 8
					automovement = FALSE
					L.adjustBruteLoss(65)
					return FALSE
		// ... and move this train
		src.Move(tgtt)
		return TRUE
	return FALSE
/obj/structure/trains/proc/rail_canmove(mdir=dir)
	var/turf/tgtt = get_step(src,mdir)
	if (!tgtt)
		return FALSE
	for (var/obj/structure/rails/R in tgtt)
		if (mdir == 1 || mdir == 2)
			if (R.dir == 1 || R.dir == 2)
				return TRUE
		else if (mdir == 4 || mdir == 8)
			if (R.dir == 4 || R.dir == 4)
				return TRUE
			return TRUE
	return FALSE

/obj/structure/trains/storage
	var/max_storage = 7
	var/obj/item/weapon/storage/internal/storage


/obj/structure/trains/storage/New()
	..()
	storage = new/obj/item/weapon/storage/internal(src)
	storage.storage_slots = max_storage
	storage.max_w_class = 5
	storage.max_storage_space = max_storage*5
	update_icon()

/obj/structure/trains/storage/Destroy()
	qdel(storage)
	storage = null
	..()

/obj/structure/trains/storage/attack_hand(mob/user as mob)
	if (istype(user, /mob/living/carbon/human) && user in range(1,src))
		storage.open(user)
		update_icon()
	else
		return
/obj/structure/trains/storage/MouseDrop(obj/over_object as obj)
	if (storage.handle_mousedrop(usr, over_object))
		..(over_object)
		update_icon()

/obj/structure/trains/storage/attackby(obj/item/W as obj, mob/user as mob)
	..()
	storage.attackby(W, user)
	update_icon()

/obj/structure/trains/storage/miningcart
	name = "mining cart"
	desc = "A wooden mining cart, for underground rails."
	icon_state = "miningcar"

//////////////////////////////////////////////////////////////////////////////////
/obj/structure/trains/transport
	name = "flatbed cart"
	icon_state = "flatbed"
	can_buckle = TRUE
	buckle_lying = FALSE

/obj/structure/trains/transport/MouseDrop_T(atom/movable/M, mob/living/user)
	if (!istype(user, /mob/living))
		return
	if  (!istype(M, /mob/living))
		if (istype(M, /obj/item))
			var/obj/AM = M
			if (!AM.anchored)
				visible_message("[user] starts dragging \the [AM] into \the [src]...", "You start dragging \the [AM] into \the [src]...")
				if (do_after(user, 50, src))
					visible_message("[user] drags \the [AM] into \the [src].", "You drag \the [AM] into \the [src].")
					AM.forceMove(src.loc)
					AM.anchored = TRUE
					transporting += AM
					return
	if (M.loc == src.loc)
		buckle_mob(M)
		if (user == M)
			user << "You buckle yourself to \the [src]."
		else
			visible_message("[user] buckles [M] to \the [src].","You buckle [M] to \the [src].")
		return
	else
		if (user == M)
			user << "You start climbing into \the [src]..."
		else
			visible_message("[user] starts dragging [M] into \the [src]...", "You start dragging [M] into \the [src]...")
		if (do_after(user, 50, src))
			if (user == M)
				user << "You climb into \the [src]."
			else
				visible_message("[user] drags [M] into \the [src].", "You drag [M] into \the [src].")
			M.forceMove(src.loc)
		return
/obj/structure/trains/transport/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/grab))
		var/obj/item/weapon/grab/G = W
		var/mob/living/affecting = G.affecting
		user.visible_message("<span class='notice'>[user] attempts to buckle [affecting] into \the [src]!</span>")
		if (do_after(user, 20, src))
			affecting.loc = loc
			spawn(0)
				if (buckle_mob(affecting))
					affecting.visible_message(\
						"<span class='danger'>[affecting.name] is buckled to [src] by [user.name]!</span>",\
						"<span class='danger'>You are buckled to [src] by [user.name]!</span>",\
						"<span class='notice'>You hear metal clanking.</span>")
			qdel(W)
	else
		if (istype(W, /obj/item/weapon))
			switch(W.damtype)
				if ("fire")
					health -= W.force * TRUE
				if ("brute")
					health -= W.force * 0.75
		else
			..()


/obj/structure/trains/transport/user_unbuckle_mob(mob/user)
	var/mob/living/M = unbuckle_mob()
	if (M)
		if (M != user)
			M.visible_message(\
				"<span class='notice'>[M.name] was unbuckled by [user.name]!</span>",\
				"<span class='notice'>You were unbuckled from [src] by [user.name].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		else
			M.visible_message(\
				"<span class='notice'>[M.name] unbuckled themselves!</span>",\
				"<span class='notice'>You unbuckle yourself from [src].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		add_fingerprint(user)
		for(var/turf/floor/F in range(1,src))
			for(var/obj/O in F)
				if (!O.density && !F.density)
					M.forceMove(F)
					return M
	return M
/////////////////////////////////////////////////////////////////////////////////////////////
/obj/structure/trains/locomotive
	name = "locomotive"
	icon_state = "tractor"
	train_speed = 8 //deciseconds of delay, so lower is better
	locomotive = TRUE
	var/on = FALSE
/obj/structure/trains/locomotive/attack_hand(mob/living/user as mob)
	if (!istype(user, /mob/living))
		return
	if (on)
		on = FALSE
		visible_message("[user] turns off \the [src].", "You turn off \the [src].")
		automovement = FALSE
		update_icon()
		return
	else
		on = TRUE
		visible_message("[user] turns on \the [src].", "You turn on \the [src].")
		locomotive()
		update_icon()
		return
	..()

/obj/structure/trains/locomotive/proc/locomotive()
	if (!on)
		return
	if (!automovement)
		automovement = TRUE
		playsound(src.loc, 'sound/machines/train/moving.ogg', 100, TRUE)
		rail_movement()
		return