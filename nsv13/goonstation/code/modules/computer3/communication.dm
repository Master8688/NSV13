
#define MENU_MAIN 0
#define MENU_CALL 1

/datum/computer/file/terminal_program/communications
	name = "COMMaster"
	size = 16
	req_access = list(ACCESS_HEADS)
	var/tmp/menu = MENU_MAIN
	var/tmp/authenticated = null //Are we currently logged in?
	var/datum/computer/file/user_data/account = null
	var/obj/item/peripheral/network/radio/radiocard = null
	var/obj/item/peripheral/network/powernet_card/pnet_card = null
	var/tmp/comm_net_id = null //The net id of our linked ~comm dish~
	var/tmp/reply_wait = -1 //How long do we wait for replies? -1 is not waiting.

	var/setup_acc_filepath = "/logs/sysusr"//Where do we look for login data?

	initialize()

		src.authenticated = null
		src.master.temp = null
		if(!src.find_access_file()) //Find the account information, as it's essentially a ~digital ID card~
			src.print_text("<b>Error:</b> Cannot locate user file.  Quitting...")
			src.master.unload_program(src) //Oh no, couldn't find the file.
			return

		src.radiocard = locate() in src.master.peripherals
		if(!radiocard || !istype(src.radiocard))
			src.radiocard = null
			src.print_text("<b>Warning:</b> No radio module detected.")

		src.pnet_card = locate() in src.master.peripherals
		if(!pnet_card || !istype(src.pnet_card))
			src.pnet_card = null
			src.print_text("<b>Warning:</b> No network adapter detected.")

		if(!src.check_access(src.account.access))
			src.print_text("User [src.account.registered] does not have needed access credentials.<br>Quitting...")
			src.master.unload_program(src)
			return

		src.reply_wait = -1
		src.authenticated = src.account.registered

		src.print_shuttle_status()
		src.print_intro_text()


	proc/print_intro_text()
		var/intro_text = {"<br>Welcome to COMMaster!
		<br>InterStation Communication System.
		<br><b>Commands:</b>
		<br>(Status) to view current status.
		<br>(Link) to link with a comm array.
		<br>(Call) to call shuttle.
		<br>(Recall) to recall shuttle.
		<br>(Clear) to clear the screen.
		<br>(Quit) to exit COMMaster."}
		src.print_text(intro_text)

	input_text(text)
		if(..())
			return

		var/list/command_list = parse_string(text)
		var/command = command_list[1]
		command_list -= command_list[1] //Remove the command we are now processing.

		switch(menu)
			if(MENU_MAIN)
				switch(lowertext(command))
					if("status")
						src.print_shuttle_status()
					if("link")
						if(!src.pnet_card) //can't do this ~fancy network stuff~ without a network card.
							src.print_text("<b>Error:</b> Network card required.")
							src.master.add_fingerprint(usr)
							return

						src.print_text("Now scanning for communications array...")
						src.detect_comm_dish()

					if("call")
/*
						if (isghostdrone(usr))
							src.print_text("<b>Error:</b> Permission denied.")
							return
*/
						if(!src.pnet_card)
							src.print_text("<b>Error:</b> Network card required.")
							src.master.add_fingerprint(usr)
							return

						if(!src.comm_net_id)
							src.detect_comm_dish()
							sleep(8)
							if (!src.comm_net_id)
								src.print_text("<b>Error:</b> Unable to detect comm dish.  Please check network cabling.")
								return

						//if (signal_loss >= 75)
						#warn FORCED-FALSE IFSTATEMENT (WARNUSR-1)
							src.print_text("Severe signal interference is preventing contact with the Emergency Shuttle.")
						else
							src.print_text("Please type and enter the nature of the emergency:")
							menu = MENU_CALL

					if("recall")
					/*
						if (isghostdrone(usr))
							src.print_text("<b>Error:</b> Permission denied.")
							return
					*/
						if(!src.pnet_card)
							src.print_text("<b>Error:</b> Network card required.")
							src.master.add_fingerprint(usr)
							return

						if(isAI(usr) || src.authenticated == "AIUSR")
							src.print_text("<b>Error:</b> Shuttle recall from AIUSR blocked by Central Command.")
							return

						if(!src.comm_net_id)
							src.detect_comm_dish()
							sleep(8)
							if (!src.comm_net_id)
								src.print_text("<b>Error:</b> Unable to detect comm dish.  Please check network cabling.")
								return

						//if (signal_loss >= 75)
						#warn FORCED-FALSE IFSTATEMENT (WARNUSR-1)
						if(FALSE)
							src.print_text("Severe signal interference is preventing contact with the Emergency Shuttle.")
						else
							src.print_text("Transmitting recall request...")
							generate_signal(comm_net_id, "command", "recall", "shuttle_id", "emergency", "acc_code", GLOB.netpass_heads)

					if("help")
						var/help_text = {"<b>Commands:</b>
						<br>(Status) to view current status.
						<br>(Link) to link with a comm array.
						<br>(Call) to call shuttle.
						<br>(Recall) to recall shuttle.
						<br>(Clear) to clear the screen.
						<br>(Quit) to exit COMMaster."}
						src.print_text(help_text)

					if("clear")
						src.master.temp = null
						src.master.temp_add = "Workspace cleared.<br>"

					if("quit")
						src.master.temp = ""
						print_text("Now quitting...")
						src.master.unload_program(src)
						return

					else
						print_text("Unknown command : \"[copytext(strip_html(command), 1, 16)]\"")
			if(MENU_CALL)
				// we don't know how long it's been since last input, check we can transmit again
				menu = MENU_MAIN
				/* //Thankfully we don't have any of these pricks -FRANC
				if (isghostdrone(usr))
					src.print_text("<b>Error:</b> Permission denied.")
					return
				*/
				if(!src.pnet_card)
					src.print_text("<b>Error:</b> Network card required.")
					src.master.add_fingerprint(usr)
					return

				if(!src.comm_net_id)
					src.detect_comm_dish()
					sleep(8)
					if (!src.comm_net_id)
						src.print_text("<b>Error:</b> Unable to detect comm dish.  Please check network cabling.")
						return
/*
				if (signal_loss >= 75)
					src.print_text("Severe signal interference is preventing contact with the Emergency Shuttle, aborting.")
					return
*/
				var/call_reason = copytext(html_decode(trim(strip_html(html_decode(text)))), 1, 140)
				src.print_text("Transmitting call request...")
				generate_signal(comm_net_id, "command", "call", "shuttle_id", "emergency", "acc_code", netpass_heads, "reason", GLOB.call_reason)
				log_game("[usr] attempted to call the Emergency Shuttle via COMMaster (reason: [call_reason])")
				//logTheThing("diary", usr, null, "attempted to call the Emergency Shuttle via COMMaster (reason: [call_reason])", "admin")
				message_admins("<span style=\"color:blue\">[key_name(usr)] attempted to call the Emergency Shuttle to the station via COMMaster</span>")


		src.master.add_fingerprint(usr)
		src.master.updateUsrDialog()
		return

	process()
		if(..())
			return

		if(src.reply_wait > 0)
			src.reply_wait--
			if(src.reply_wait == 0)
				src.print_text("Timed out on Dish. Please rescan and retry.")
				src.comm_net_id = null

	receive_command(obj/source, command, datum/signal/signal)
		if((..()) || (!signal))
			return

		//If we don't have a comm dish net_id to use, set one.
		switch(signal.data["command"])
			if("ping_reply")
				if(src.comm_net_id)
					return
				if((signal.data["device"] != "PNET_COM_ARRAY") || !signal.data["netid"])
					return

				src.comm_net_id = signal.data["netid"]
				src.print_text("Communications array detected.")
			if("device_reply")
				if(!src.comm_net_id || signal.data["sender"] != src.comm_net_id)
					return

				src.reply_wait = -1

				switch(lowertext(signal.data["status"]))
					if("shutl_e_dis")
						src.print_text("<b>Alert:</b> Shuttle command request rejected!")

					if("shutl_e_sen")
						src.print_text("<b>Alert:</b> The Emergency Shuttle has been called.")
						if(master && master.current_user)
							message_admins("<span style=\"color:blue\">[key_name(master.current_user)] called the Emergency Shuttle to the station</span>")
							logTheThing("station", null, null, "[key_name(master.current_user)] called the Emergency Shuttle to the station")

					if("shutl_e_ret")
						src.print_text("<b>Alert:</b> The Emergency Shuttle has been recalled.")
						if(master && master.current_user)
							message_admins("<span style=\"color:blue\">[key_name(master.current_user)] recalled the Emergency Shuttle</span>")
							logTheThing("station", null, null, "[key_name(master.current_user)] recalled the Emergency Shuttle")

				return


		return

	proc
		find_access_file() //Look for the whimsical account_data file
			var/datum/computer/folder/accdir = src.holder.root
			if(src.master.host_program) //Check where the OS is, preferably.
				accdir = src.master.host_program.holder.root

			var/datum/computer/file/user_data/target = parse_file_directory(setup_acc_filepath, accdir)
			if(target && istype(target))
				src.account = target
				return 1

			return 0

		detect_comm_dish() //Send out a ping signal to find a comm dish.
			if(!src.pnet_card)
				return //The card is kinda crucial for this.

			var/datum/signal/newsignal = new(src)
			//newsignal.encryption = "\ref[src.pnet_card]"

			src.comm_net_id = null
			src.reply_wait = -1
			src.peripheral_command("ping", newsignal, "\ref[src.pnet_card]")

		// i take it this proc was written before varargs were a thing - cirr, 2017
		generate_signal(var/target_id, var/key, var/value, var/key2, var/value2, var/key3, var/value3, var/key4, var/value4)
			if(!src.pnet_card || !comm_net_id)
				return

			var/datum/signal/signal = new(src)
			//signal.encryption = "\ref[src.pnet_card]"
			signal.data["address_1"] = target_id
			signal.data[key] = value
			if(key2)
				signal.data[key2] = value2
			if(key3)
				signal.data[key3] = value3
			if(key4)
				signal.data[key4] = value4

			src.reply_wait = 5
			src.peripheral_command("transmit", signal, "\ref[src.pnet_card]")



		print_shuttle_status()
			var/dat = "<b>Status</b>: "
			if (SSshuttle.emergency.mode == SHUTTLE_IDLE)
				dat += "No shuttles currently en route."
			else
				dat += "<b>Emergency shuttle</b><br>[SSshuttle.getModeStr()]: [SSshuttle.emergency.getTimerStr()]"


			src.print_text(dat)

			return

#undef MENU_MAIN
#undef MENU_CALL