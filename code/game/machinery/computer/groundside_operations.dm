#define COMMAND_SQUAD "Command"

#define HIDE_ALMAYER 2
#define HIDE_GROUND 1
#define HIDE_NONE 0

/obj/structure/machinery/computer/groundside_operations
	name = "groundside operations console"
	desc = "This can be used for various important functions."
	icon_state = "comm"
	req_access = list(ACCESS_MARINE_SENIOR)
	unslashable = TRUE
	unacidable = TRUE

	/// making an announcement
	COOLDOWN_DECLARE(announcement_cooldown)

	var/list/messagetitle = list()
	var/list/messagetext = list()

	var/obj/structure/machinery/camera/cam = null
	var/datum/squad/current_squad = null

	var/datum/tacmap/tacmap
	var/minimap_type = MINIMAP_FLAG_USCM

	var/is_announcement_active = TRUE
	var/announcement_title = COMMAND_ANNOUNCE
	var/announcement_faction = FACTION_MARINE
	var/add_pmcs = TRUE
	var/lz_selection = TRUE
	var/has_squad_overwatch = TRUE
	var/faction = FACTION_MARINE 
	var/show_command_squad = FALSE

	var/z_hidden = 0 //which z level is ignored when showing marines.
	var/marine_filter = list() // individual marine hiding control - list of string references
	var/marine_filter_enabled = TRUE

	var/list/squad_list = list()
			

/obj/structure/machinery/computer/groundside_operations/Initialize()
	if (current_squad == null)
		current_squad = GLOB.RoleAuthority.squads_by_type[/datum/squad/marine]
	if(SSticker.mode && MODE_HAS_FLAG(MODE_FACTION_CLASH))
		add_pmcs = FALSE
	else if(SSticker.current_state < GAME_STATE_PLAYING)
		RegisterSignal(SSdcs, COMSIG_GLOB_MODE_PRESETUP, PROC_REF(disable_pmc))
	if(announcement_faction == FACTION_MARINE)
		tacmap = new /datum/tacmap/drawing(src, minimap_type)
	else
		tacmap = new(src, minimap_type) // Non-drawing version

	return ..()

/obj/structure/machinery/computer/groundside_operations/Destroy()
	QDEL_NULL(tacmap)
	QDEL_NULL(cam)
	current_squad = null
	return ..()

/obj/structure/machinery/computer/groundside_operations/proc/disable_pmc()
	if(MODE_HAS_FLAG(MODE_FACTION_CLASH))
		add_pmcs = FALSE
	UnregisterSignal(SSdcs, COMSIG_GLOB_MODE_PRESETUP)

/obj/structure/machinery/computer/groundside_operations/attack_remote(mob/user as mob)
	return attack_hand(user)

/obj/structure/machinery/computer/groundside_operations/attack_hand(mob/user as mob)
	if(..() || inoperable())
		return

	if(!allowed(user))
		to_chat(usr, SPAN_WARNING("Access denied."))
		return FALSE

	if(!istype(loc.loc, /area/almayer/command/cic)) //Has to be in the CIC. Can also be a generic CIC area to communicate, if wanted.
		to_chat(usr, SPAN_WARNING("Unable to establish a connection."))
		return FALSE

	tgui_interact(user)

/obj/structure/machinery/computer/groundside_operations/tgui_interact(mob/user, datum/tgui/ui, datum/ui_state/state)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OperationControl", "[name]")
		ui.open()

/obj/structure/machinery/computer/groundside_operations/ui_status(mob/user, datum/ui_state/state)
	. = ..()
	if(!allowed(user))
		return UI_CLOSE
	if(!operable())
		return UI_CLOSE

/obj/structure/machinery/computer/groundside_operations/ui_state(mob/user)
	return GLOB.not_incapacitated_and_adjacent_strict_state

// tgui data \\

/obj/structure/machinery/computer/groundside_operations/ui_static_data(mob/user)
	var/list/data = list()

	data["cooldown_message"] = COOLDOWN_COMM_MESSAGE

	return data

/obj/structure/machinery/computer/groundside_operations/ui_data(mob/user)
	var/list/data = list()
	var/list/messages = list()

	data["selected_squad"] = current_squad
	data["show_command_squad"] = show_command_squad

	data["endtime"] = announcement_cooldown

	data["worldtime"] = world.time

	data["selected_LZ"] = SSticker.mode.active_lz

	data["current_squad"] = current_squad.name
	data["marines"] = list()

	var/leader_count = 0
	var/ftl_count = 0
	var/spec_count = 0
	var/medic_count = 0
	var/engi_count = 0
	var/smart_count = 0
	var/marine_count = 0

	var/leaders_alive = 0
	var/ftl_alive = 0
	var/spec_alive= 0
	var/medic_alive= 0
	var/engi_alive = 0
	var/smart_alive = 0
	var/marines_alive = 0

	var/specialist_type

	var/SL_z //z level of the Squad Leader
	if(current_squad.squad_leader)
		var/turf/SL_turf = get_turf(current_squad.squad_leader)
		SL_z = SL_turf.z

	for(var/marine in current_squad.marines_list)
		if(!marine)
			continue //just to be safe
		var/mob_name = "unknown"
		var/mob_state = ""
		var/has_helmet = TRUE
		var/role = "unknown"
		var/acting_sl = ""
		var/fteam = ""
		var/distance = "???"
		var/area_name = "???"
		var/is_squad_leader = FALSE
		var/mob/living/carbon/human/marine_human


		if(ishuman(marine))
			marine_human = marine
			if(istype(marine_human.loc, /obj/structure/machinery/cryopod)) //We don't care much for these
				continue
			mob_name = marine_human.real_name
			var/area/current_area = get_area(marine_human)
			var/turf/current_turf = get_turf(marine_human)
			if(!current_turf)
				continue
			if(current_area)
				area_name = sanitize_area(current_area.name)

			switch(z_hidden)
				if(HIDE_ALMAYER)
					if(is_mainship_level(current_turf.z))
						continue
				if(HIDE_GROUND)
					if(is_ground_level(current_turf.z))
						continue

			if(marine_human.job)
				role = marine_human.job
			else if(istype(marine_human.wear_id, /obj/item/card/id)) //decapitated marine is mindless,
				var/obj/item/card/id/ID = marine_human.wear_id //we use their ID to get their role.
				if(ID.rank)
					role = ID.rank


			if(current_squad.squad_leader)
				if(marine_human == current_squad.squad_leader)
					distance = "N/A"
					if(current_squad.name == SQUAD_SOF)
						if(marine_human.job == JOB_MARINE_RAIDER_CMD)
							acting_sl = " (direct command)"
						else if(marine_human.job != JOB_MARINE_RAIDER_SL)
							acting_sl = " (acting TL)"
					else if(marine_human.job != JOB_SQUAD_LEADER)
						acting_sl = " (acting SL)"
					is_squad_leader = TRUE
				else if(current_turf && (current_turf.z == SL_z))
					distance = "[get_dist(marine_human, current_squad.squad_leader)] ([dir2text_short(Get_Compass_Dir(current_squad.squad_leader, marine_human))])"


			switch(marine_human.stat)
				if(CONSCIOUS)
					mob_state = "Conscious"

				if(UNCONSCIOUS)
					mob_state = "Unconscious"

				if(DEAD)
					mob_state = "Dead"

			if(!istype(marine_human.head, /obj/item/clothing/head/helmet/marine))
				has_helmet = FALSE

			if(!marine_human.key || !marine_human.client)
				if(marine_human.stat != DEAD)
					mob_state += " (SSD)"


			if(marine_human.assigned_fireteam)
				fteam = " [marine_human.assigned_fireteam]"

		else //listed marine was deleted or gibbed, all we have is their name
			for(var/datum/data/record/marine_record as anything in GLOB.data_core.general)
				if(marine_record.fields["name"] == marine)
					role = marine_record.fields["real_rank"]
					break
			mob_state = "Dead"
			mob_name = marine


		switch(role)
			if(JOB_SQUAD_LEADER)
				leader_count++
				if(mob_state != "Dead")
					leaders_alive++
			if(JOB_SQUAD_TEAM_LEADER)
				ftl_count++
				if(mob_state != "Dead")
					ftl_alive++
			if(JOB_SQUAD_SPECIALIST)
				spec_count++
				if(marine_human)
					if(istype(marine_human.wear_id, /obj/item/card/id)) //decapitated marine is mindless,
						var/obj/item/card/id/ID = marine_human.wear_id //we use their ID to get their role.
						if(ID.assignment)
							if(specialist_type)
								specialist_type = "MULTIPLE"
							else
								var/list/spec_type = splittext(ID.assignment, "(")
								if(islist(spec_type) && (length(spec_type) > 1))
									specialist_type = splittext(spec_type[2], ")")[1]
				else if(!specialist_type)
					specialist_type = "UNKNOWN"
				if(mob_state != "Dead")
					spec_alive++
			if(JOB_SQUAD_MEDIC)
				medic_count++
				if(mob_state != "Dead")
					medic_alive++
			if(JOB_SQUAD_ENGI)
				engi_count++
				if(mob_state != "Dead")
					engi_alive++
			if(JOB_SQUAD_SMARTGUN)
				smart_count++
				if(mob_state != "Dead")
					smart_alive++
			if(JOB_SQUAD_MARINE)
				marine_count++
				if(mob_state != "Dead")
					marines_alive++

		var/marine_data = list(list("name" = mob_name, "state" = mob_state, "has_helmet" = has_helmet, "role" = role, "acting_sl" = acting_sl, "fteam" = fteam, "distance" = distance, "area_name" = area_name,"ref" = REF(marine)))
		data["marines"] += marine_data
		if(is_squad_leader)
			if(!data["squad_leader"])
				data["squad_leader"] = marine_data[1]

	data["total_deployed"] = leader_count + ftl_count + spec_count + medic_count + engi_count + smart_count + marine_count
	data["living_count"] = leaders_alive + ftl_alive + spec_alive + medic_alive + engi_alive + smart_alive + marines_alive

	data["leader_count"] = leader_count
	data["ftl_count"] = ftl_count
	data["spec_count"] = spec_count
	data["medic_count"] = medic_count
	data["engi_count"] = engi_count
	data["smart_count"] = smart_count

	data["leaders_alive"] = leaders_alive
	data["ftl_alive"] = ftl_alive
	data["spec_alive"] = spec_alive
	data["medic_alive"] = medic_alive
	data["engi_alive"] = engi_alive
	data["smart_alive"] = smart_alive
	data["specialist_type"] = specialist_type ? specialist_type : "NONE"

	data["z_hidden"] = z_hidden

	if(!messagetitle.len)
		data["messages"] = null
	else
		for(var/i in 1 to length(messagetitle))
			var/list/messagedata = list(list(
				"title" = messagetitle[i],
				"text" = messagetext[i],
				"number" = i
			))
			messages += messagedata

		data["messages"] = messages

	return data

// end tgui data \\

// tgui interact \\

/obj/structure/machinery/computer/groundside_operations/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	switch(action)
		if("announce")
			var/mob/living/carbon/human/human_user = usr
			var/obj/item/card/id/idcard = human_user.get_active_hand()
			var/bio_fail = FALSE
			if(!istype(idcard))
				idcard = human_user.wear_id
			if(!istype(idcard))
				bio_fail = TRUE
			else if(!idcard.check_biometrics(human_user))
				bio_fail = TRUE
			if(bio_fail)
				to_chat(human_user, SPAN_WARNING("Biometrics failure! You require an authenticated ID card to perform this action!"))
				return FALSE

			if(usr.client.prefs.muted & MUTE_IC)
				to_chat(usr, SPAN_DANGER("You cannot send Announcements (muted)."))
				return

			if(!is_announcement_active)
				to_chat(usr, SPAN_WARNING("Please allow at least [COOLDOWN_COMM_MESSAGE*0.1] second\s to pass between announcements."))
				return FALSE
			if(announcement_faction != FACTION_MARINE && usr.faction != announcement_faction)
				to_chat(usr, SPAN_WARNING("Access denied."))
				return
			var/input = stripped_multiline_input(usr, "Please write a message to announce to the station crew.", "Priority Announcement", "")
			if(!input || !is_announcement_active || !(usr in view(1,src)))
				return FALSE

			is_announcement_active = FALSE

			var/signed = null
			if(ishuman(usr))
				var/mob/living/carbon/human/H = usr
				var/obj/item/card/id/id = H.wear_id
				if(istype(id))
					var/paygrade = get_paygrades(id.paygrade, FALSE, H.gender)
					signed = "[paygrade] [id.registered_name]"

			COOLDOWN_START(src, announcement_cooldown, COOLDOWN_COMM_MESSAGE)
			marine_announcement(input, announcement_title, faction_to_display = announcement_faction, add_PMCs = add_pmcs, signature = signed)
			addtimer(CALLBACK(src, PROC_REF(reactivate_announcement), usr), COOLDOWN_COMM_MESSAGE)
			message_admins("[key_name(usr)] has made a command announcement.")
			log_announcement("[key_name(usr)] has announced the following: [input]")
			
		if("mapview")
			tacmap.tgui_interact(usr)
			return

		if("activate_echo")
			var/mob/living/carbon/human/human_user = usr
			var/obj/item/card/id/idcard = human_user.get_active_hand()
			var/bio_fail = FALSE
			if(!istype(idcard))
				idcard = human_user.wear_id
			if(!istype(idcard))
				bio_fail = TRUE
			else if(!idcard.check_biometrics(human_user))
				bio_fail = TRUE
			if(bio_fail)
				to_chat(human_user, SPAN_WARNING("Biometrics failure! You require an authenticated ID card to perform this action!"))
				return FALSE

			var/reason = strip_html(input(usr, "What is the purpose of Echo Squad?", "Activation Reason"))
			if(!reason)
				return
			if(alert(usr, "Confirm activation of Echo Squad for [reason]", "Confirm Activation", "Yes", "No") != "Yes") return
			var/datum/squad/marine/echo/echo_squad = locate() in GLOB.RoleAuthority.squads
			if(!echo_squad)
				visible_message(SPAN_BOLDNOTICE("ERROR: Unable to locate Echo Squad database."))
				return
			echo_squad.engage_squad(TRUE)
			message_admins("[key_name(usr)] activated Echo Squad for '[reason]'.")

		if("selectlz")
			if(SSticker.mode.active_lz)
				return
			var/lz_choices = list("lz1", "lz2")
			var/new_lz = tgui_input_list(usr, "Select primary LZ", "LZ Select", lz_choices)
			if(!new_lz)
				return
			if(new_lz == "lz1")
				SSticker.mode.select_lz(locate(/obj/structure/machinery/computer/shuttle/dropship/flight/lz1))
			else
				SSticker.mode.select_lz(locate(/obj/structure/machinery/computer/shuttle/dropship/flight/lz2))
			message_admins("[key_name(usr)] selected '[new_lz]'.")

		if("pick_squad")
			squad_list = list()
			for(var/datum/squad/S in GLOB.RoleAuthority.squads)
				if(S.active && S.faction == faction)
					squad_list += S.name
			squad_list += COMMAND_SQUAD

			var/name_sel = tgui_input_list(usr, "Which squad would you like to look at?", "Pick Squad", squad_list)
			message_admins("[key_name(usr)] selected '[name_sel]'.")
			if(!name_sel)
				return

			if(name_sel == COMMAND_SQUAD)
				show_command_squad = TRUE
				current_squad = null

			else
				show_command_squad = FALSE

				var/datum/squad/selected = get_squad_by_name(name_sel)
				if(selected)
					current_squad = selected
				else
					to_chat(usr, "[icon2html(src, usr)] [SPAN_WARNING("Invalid input. Aborting.")]")

		if("watch_camera")
			if(isRemoteControlling(user))
				to_chat(user, "[icon2html(src, user)] [SPAN_WARNING("Unable to override console camera viewer. Track with camera instead. ")]")
				return
			if(!params["target_ref"])
				to_chat(user, SPAN_WARNING("no parameter found i guess"))
				return
			if(current_squad)
				var/mob/cam_target = locate(params["target_ref"])
				var/obj/structure/machinery/camera/new_cam = get_camera_from_target(cam_target)
				if(!new_cam || !new_cam.can_use())
					to_chat(user, "[icon2html(src, user)] [SPAN_WARNING("Searching for helmet cam. No helmet cam found for this marine! Tell your squad to put their helmets on!")]")
				else if(cam && cam == new_cam)//click the camera you're watching a second time to stop watching.
					visible_message("[icon2html(src, viewers(src))] [SPAN_BOLDNOTICE("Stopping helmet cam view of [cam_target].")]")
					user.UnregisterSignal(cam, COMSIG_PARENT_QDELETING)
					cam = null
					user.reset_view(null)
				else if(user.client.view != GLOB.world_view_size)
					to_chat(user, SPAN_WARNING("You're too busy peering through binoculars."))
				else
					to_chat(user, SPAN_WARNING("test 1"))
					if(cam)
						to_chat(user, SPAN_WARNING("test 2"))
						user.UnregisterSignal(cam, COMSIG_PARENT_QDELETING)
					cam = new_cam
					user.reset_view(cam)
					user.RegisterSignal(cam, COMSIG_PARENT_QDELETING, TYPE_PROC_REF(/mob, reset_observer_view_on_deletion))


/obj/structure/machinery/computer/overwatch/check_eye(mob/user)
	if(user.is_mob_incapacitated(TRUE) || get_dist(user, src) > 1 || user.blinded) //user can't see - not sure why canmove is here.
		user.unset_interaction()
	else if(!cam || !cam.can_use()) //camera doesn't work, is no longer selected or is gone
		user.unset_interaction()

/obj/structure/machinery/computer/overwatch/on_unset_interaction(mob/user)
	..()
	if(!isRemoteControlling(user))
		if(cam)
			user.UnregisterSignal(cam, COMSIG_PARENT_QDELETING)
		cam = null
		user.reset_view(null)

/obj/structure/machinery/computer/overwatch/ui_close(mob/user)
	..()
	if(!isRemoteControlling(user))
		if(cam)
			user.UnregisterSignal(cam, COMSIG_PARENT_QDELETING)
		cam = null
		user.reset_view(null)

/obj/structure/machinery/computer/groundside_operations/ui_interact(mob/user as mob)
	user.set_interaction(src)

	var/dat = "<head><title>Groundside Operations Console</title></head><body>"
	dat += "<BR><A HREF='?src=\ref[src];operation=announce'>[is_announcement_active ? "Make An Announcement" : "*Unavailable*"]</A>"
	dat += "<BR><A href='?src=\ref[src];operation=mapview'>Tactical Map</A>"
	dat += "<BR><hr>"
	var/datum/squad/marine/echo/echo_squad = locate() in GLOB.RoleAuthority.squads
	if(!echo_squad.active && faction == FACTION_MARINE)
		dat += "<BR><A href='?src=\ref[src];operation=activate_echo'>Designate Echo Squad</A>"
		dat += "<BR><hr>"

	if(lz_selection && SSticker.mode && (isnull(SSticker.mode.active_lz) || isnull(SSticker.mode.active_lz.loc)))
		dat += "<BR><A href='?src=\ref[src];operation=selectlz'>Designate Primary LZ</A><BR>"
		dat += "<BR><hr>"

	if(has_squad_overwatch)
		if(show_command_squad)
			dat += "Current Squad: <A href='?src=\ref[src];operation=pick_squad'>Command</A><BR>"
		else
			dat += "Current Squad: <A href='?src=\ref[src];operation=pick_squad'>[!isnull(current_squad) ? "[current_squad.name]" : "----------"]</A><BR>"
		if(current_squad || show_command_squad)
			dat += get_overwatch_info()

	dat += "<BR><A HREF='?src=\ref[user];mach_close=groundside_operations'>Close</A>"
	show_browser(user, dat, name, "groundside_operations", "size=600x700")
	onclose(user, "groundside_operations")

/obj/structure/machinery/computer/groundside_operations/proc/get_overwatch_info()
	var/dat = ""
	dat += {"
	<script type="text/javascript">
		function updateSearch() {
			var filter_text = document.getElementById("filter");
			var filter = filter_text.value.toLowerCase();

			var marine_list = document.getElementById("marine_list");
			var ltr = marine_list.getElementsByTagName("tr");

			for(var i = 0; i < ltr.length; ++i) {
				try {
					var tr = ltr\[i\];
					tr.style.display = '';
					var ltd = tr.getElementsByTagName("td")
					var name = ltd\[0\].innerText.toLowerCase();
					var role = ltd\[1\].innerText.toLowerCase()
					if(name.indexOf(filter) == -1 && role.indexOf(filter) == -1) {
						tr.style.display = 'none';
					}
				} catch(err) {}
			}
		}
	</script>
	"}

	if(show_command_squad)
		dat += format_list_of_marines(list(GLOB.marine_leaders[JOB_CO], GLOB.marine_leaders[JOB_XO]) + GLOB.marine_leaders[JOB_SO], list(JOB_CO, JOB_XO, JOB_SO))
	else if(current_squad)
		dat += format_list_of_marines(current_squad.marines_list, list(JOB_SQUAD_LEADER, JOB_SQUAD_SPECIALIST, JOB_SQUAD_MEDIC, JOB_SQUAD_ENGI, JOB_SQUAD_SMARTGUN, JOB_SQUAD_MARINE))
	else
		dat += "No Squad selected!<BR>"
	dat += "<br><hr>"
	dat += "<A href='?src=\ref[src];operation=refresh'>Refresh</a><br>"
	return dat

/obj/structure/machinery/computer/groundside_operations/proc/format_list_of_marines(list/mob/living/carbon/human/marine_list, list/jobs_in_order)
	var/dat = ""
	var/list/job_order = list()

	for(var/job in jobs_in_order)
		job_order[job] = ""

	var/misc_text = ""

	var/living_count = 0
	var/almayer_count = 0
	var/SSD_count = 0
	var/helmetless_count = 0
	var/total_count = 0

	for(var/X in marine_list)
		if(!X)
			continue //just to be safe
		total_count++
		var/mob_name = "unknown"
		var/mob_state = ""
		var/role = "unknown"
		var/area_name = "<b>???</b>"
		var/mob/living/carbon/human/H
		var/act_sl = ""
		if(ishuman(X))
			H = X
			mob_name = H.real_name
			var/area/A = get_area(H)
			var/turf/M_turf = get_turf(H)
			if(A)
				area_name = sanitize_area(A.name)

			if(H.job)
				role = H.job
			else if(istype(H.wear_id, /obj/item/card/id)) //decapitated marine is mindless,
				var/obj/item/card/id/ID = H.wear_id //we use their ID to get their role.
				if(ID.rank)
					role = ID.rank

			switch(H.stat)
				if(CONSCIOUS)
					mob_state = "Conscious"
					living_count++
				if(UNCONSCIOUS)
					mob_state = "<b>Unconscious</b>"
					living_count++
				else
					continue

			if(!is_ground_level(M_turf.z))
				almayer_count++
				continue

			if(!istype(H.head, /obj/item/clothing/head/helmet/marine))
				helmetless_count++
				continue

			if(!H.key || !H.client)
				SSD_count++
				continue
			if(current_squad)
				if(H == current_squad.squad_leader && role != JOB_SQUAD_LEADER)
					act_sl = " (ASL)"
		var/marine_infos = "<tr><td><A href='?src=\ref[src];operation=use_cam;cam_target=\ref[H]'>[mob_name]</a></td><td>[role][act_sl]</td><td>[mob_state]</td><td>[area_name]</td></tr>"
		if(role in job_order)
			job_order[role] += marine_infos
		else
			misc_text += marine_infos
	dat += "<b>Total: [total_count] Deployed</b><BR>"
	dat += "<b>Marines detected: [living_count] ([helmetless_count] no helmet, [SSD_count] SSD, [almayer_count] on Almayer)</b><BR>"
	dat += "<center><b>Search:</b> <input type='text' id='filter' value='' onkeyup='updateSearch();' style='width:300px;'></center>"
	dat += "<table id='marine_list' border='2px' style='width: 100%; border-collapse: collapse;' align='center'><tr>"
	dat += "<th>Name</th><th>Role</th><th>State</th><th>Location</th></tr>"
	for(var/job in job_order)
		dat += job_order[job]
	dat += misc_text
	dat += "</table>"
	return dat

/obj/structure/machinery/computer/groundside_operations/Topic(href, href_list)
	if(..())
		return FALSE

	usr.set_interaction(src)
	switch(href_list["operation"])

		if("mapview")
			tacmap.tgui_interact(usr)
			return

		if("announce")
			var/mob/living/carbon/human/human_user = usr
			var/obj/item/card/id/idcard = human_user.get_active_hand()
			var/bio_fail = FALSE
			if(!istype(idcard))
				idcard = human_user.wear_id
			if(!istype(idcard))
				bio_fail = TRUE
			else if(!idcard.check_biometrics(human_user))
				bio_fail = TRUE
			if(bio_fail)
				to_chat(human_user, SPAN_WARNING("Biometrics failure! You require an authenticated ID card to perform this action!"))
				return FALSE

			if(usr.client.prefs.muted & MUTE_IC)
				to_chat(usr, SPAN_DANGER("You cannot send Announcements (muted)."))
				return

			if(!is_announcement_active)
				to_chat(usr, SPAN_WARNING("Please allow at least [COOLDOWN_COMM_MESSAGE*0.1] second\s to pass between announcements."))
				return FALSE
			if(announcement_faction != FACTION_MARINE && usr.faction != announcement_faction)
				to_chat(usr, SPAN_WARNING("Access denied."))
				return
			var/input = stripped_multiline_input(usr, "Please write a message to announce to the station crew.", "Priority Announcement", "")
			if(!input || !is_announcement_active || !(usr in view(1,src)))
				return FALSE

			is_announcement_active = FALSE

			var/signed = null
			if(ishuman(usr))
				var/mob/living/carbon/human/H = usr
				var/obj/item/card/id/id = H.wear_id
				if(istype(id))
					var/paygrade = get_paygrades(id.paygrade, FALSE, H.gender)
					signed = "[paygrade] [id.registered_name]"

			marine_announcement(input, announcement_title, faction_to_display = announcement_faction, add_PMCs = add_pmcs, signature = signed)
			addtimer(CALLBACK(src, PROC_REF(reactivate_announcement), usr), COOLDOWN_COMM_MESSAGE)
			message_admins("[key_name(usr)] has made a command announcement.")
			log_announcement("[key_name(usr)] has announced the following: [input]")

		if("award")
			open_medal_panel(usr, src)

		if("selectlz")
			if(SSticker.mode.active_lz)
				return
			var/lz_choices = list("lz1", "lz2")
			var/new_lz = tgui_input_list(usr, "Select primary LZ", "LZ Select", lz_choices)
			if(!new_lz)
				return
			if(new_lz == "lz1")
				SSticker.mode.select_lz(locate(/obj/structure/machinery/computer/shuttle/dropship/flight/lz1))
			else
				SSticker.mode.select_lz(locate(/obj/structure/machinery/computer/shuttle/dropship/flight/lz2))

		if("pick_squad")
			var/list/squad_list = list()
			for(var/datum/squad/S in GLOB.RoleAuthority.squads)
				if(S.active && S.faction == faction)
					squad_list += S.name
			squad_list += COMMAND_SQUAD

			var/name_sel = tgui_input_list(usr, "Which squad would you like to look at?", "Pick Squad", squad_list)
			if(!name_sel)
				return

			if(name_sel == COMMAND_SQUAD)
				show_command_squad = TRUE
				current_squad = null

			else
				show_command_squad = FALSE

				var/datum/squad/selected = get_squad_by_name(name_sel)
				if(selected)
					current_squad = selected
				else
					to_chat(usr, "[icon2html(src, usr)] [SPAN_WARNING("Invalid input. Aborting.")]")

		if("use_cam")
			if(isRemoteControlling(usr))
				to_chat(usr, "[icon2html(src, usr)] [SPAN_WARNING("Unable to override console camera viewer. Track with camera instead. ")]")
				return

			if(current_squad || show_command_squad)
				var/mob/cam_target = locate(href_list["cam_target"])
				var/obj/structure/machinery/camera/new_cam = get_camera_from_target(cam_target)
				if(!new_cam || !new_cam.can_use())
					to_chat(usr, "[icon2html(src, usr)] [SPAN_WARNING("Searching for helmet cam. No helmet cam found for this marine! Tell your squad to put their helmets on!")]")
				else if(cam && cam == new_cam)//click the camera you're watching a second time to stop watching.
					visible_message("[icon2html(src, viewers(src))] [SPAN_BOLDNOTICE("Stopping helmet cam view of [cam_target].")]")
					usr.UnregisterSignal(cam, COMSIG_PARENT_QDELETING)
					cam = null
					usr.reset_view(null)
				else if(usr.client.view != GLOB.world_view_size)
					to_chat(usr, SPAN_WARNING("You're too busy peering through binoculars."))
				else
					if(cam)
						usr.UnregisterSignal(cam, COMSIG_PARENT_QDELETING)
					cam = new_cam
					usr.reset_view(cam)
					usr.RegisterSignal(cam, COMSIG_PARENT_QDELETING, TYPE_PROC_REF(/mob, reset_observer_view_on_deletion))

		if("activate_echo")
			var/mob/living/carbon/human/human_user = usr
			var/obj/item/card/id/idcard = human_user.get_active_hand()
			var/bio_fail = FALSE
			if(!istype(idcard))
				idcard = human_user.wear_id
			if(!istype(idcard))
				bio_fail = TRUE
			else if(!idcard.check_biometrics(human_user))
				bio_fail = TRUE
			if(bio_fail)
				to_chat(human_user, SPAN_WARNING("Biometrics failure! You require an authenticated ID card to perform this action!"))
				return FALSE

			var/reason = strip_html(input(usr, "What is the purpose of Echo Squad?", "Activation Reason"))
			if(!reason)
				return
			if(alert(usr, "Confirm activation of Echo Squad for [reason]", "Confirm Activation", "Yes", "No") != "Yes") return
			var/datum/squad/marine/echo/echo_squad = locate() in GLOB.RoleAuthority.squads
			if(!echo_squad)
				visible_message(SPAN_BOLDNOTICE("ERROR: Unable to locate Echo Squad database."))
				return
			echo_squad.engage_squad(TRUE)
			message_admins("[key_name(usr)] activated Echo Squad for '[reason]'.")

		if("refresh")
			attack_hand(usr)

	updateUsrDialog()

/obj/structure/machinery/computer/groundside_operations/proc/reactivate_announcement(mob/user)
	is_announcement_active = TRUE
	updateUsrDialog()

/obj/structure/machinery/computer/groundside_operations/on_unset_interaction(mob/user)
	..()

	if(!isRemoteControlling(user))
		if(cam)
			user.UnregisterSignal(cam, COMSIG_PARENT_QDELETING)
		cam = null
		user.reset_view(null)

//returns the helmet camera the human is wearing
/obj/structure/machinery/computer/groundside_operations/proc/get_camera_from_target(mob/living/carbon/human/H)
	if(current_squad)
		if(H && istype(H) && istype(H.head, /obj/item/clothing/head/helmet/marine))
			var/obj/item/clothing/head/helmet/marine/helm = H.head
			return helm.camera

/obj/structure/machinery/computer/groundside_operations/upp
	announcement_title = UPP_COMMAND_ANNOUNCE
	announcement_faction = FACTION_UPP
	add_pmcs = FALSE
	lz_selection = FALSE
	has_squad_overwatch = FALSE
	minimap_type = MINIMAP_FLAG_UPP

/obj/structure/machinery/computer/groundside_operations/clf
	announcement_title = CLF_COMMAND_ANNOUNCE
	announcement_faction = FACTION_CLF
	add_pmcs = FALSE
	lz_selection = FALSE
	has_squad_overwatch = FALSE
	minimap_type = MINIMAP_FLAG_CLF

/obj/structure/machinery/computer/groundside_operations/pmc
	announcement_title = PMC_COMMAND_ANNOUNCE
	announcement_faction = FACTION_PMC
	lz_selection = FALSE
	has_squad_overwatch = FALSE
	minimap_type = MINIMAP_FLAG_PMC

#undef COMMAND_SQUAD
#undef HIDE_ALMAYER
#undef HIDE_GROUND
#undef HIDE_NONE
