note
	description: "[
		Abstract notion of a {PH_PROCESS_HELPER}.
		]"
	design: "[
		These "helper" features are designed to assist with
		use of the {PROCESS_IMP} and {PROCESS_FACTORY}.
		]"

class
	PH_PROCESS_HELPER

inherit
	ANY
		redefine
			default_create
		end

feature {NONE} -- Initialization

	default_create
			--<Precursor>
		do
			set_hide_cli
		end

feature -- Access

	process: attached like internal_process
			-- Ref to current process.
		do
			check attached internal_process as al_result then Result := al_result end
		end

	last_result: attached like last_internal_result
			-- Ref to last result.
		do
			check attached last_internal_result as al_result then Result := al_result end
		end

	last_error: INTEGER
			-- Error code of `last_error'.

	last_error_msg: detachable STRING
			-- Error message of `last_error'

feature -- Status Report

	has_file_in_path (a_name: STRING): BOOLEAN
			-- `has_file_in_path' as `a_name'?
		local
			l_result,
			l_msg: STRING
		do
			l_msg := dos_where_not_found_message.twin
			check attached {STRING_8} output_of_command ("where " + a_name, ".") as al_result then
				l_result := al_result
			end
			Result := not l_result.same_string (l_msg) xor {PLATFORM}.is_unix
		end

feature -- Basic Operations

	process_killable_command (a_id: STRING; a_command_line: READABLE_STRING_32; a_directory: detachable READABLE_STRING_32)
			--
		do
			process_command (a_command_line, a_directory)
			started_pids.put (last_pid, a_id)
		end

	process_command (a_command_line: READABLE_STRING_32; a_directory: detachable READABLE_STRING_32)
			-- `output_of_command' `a_command_line' launched in `a_directory' (e.g. "." = Current directory).
		require
			cmd_not_empty: not a_command_line.is_empty
			dir_not_empty: attached a_directory as al_dir implies not al_dir.is_empty
		local
			l_buffer: SPECIAL [NATURAL_8]
			l_result: STRING_32
			l_args: ARRAY [STRING_32]
			l_cmd: STRING_32
			l_list: LIST [READABLE_STRING_32]
		do
			l_list := a_command_line.split (' ')
			l_cmd := l_list [1]
			if l_list.count >= 2 then
				create l_args.make_filled ({STRING_32} "", 1, l_list.count - 1)
				across
					2 |..| l_list.count as ic
				loop
					l_args.put (l_list [ic.item], ic.item - 1)
				end
			end
			internal_process := (create {BASE_PROCESS_FACTORY}).process_launcher (l_cmd, l_args, a_directory)
			if attached internal_process as al_process then
				last_pid := al_process.id
				al_process.set_hidden (True)
				al_process.redirect_output_to_stream
				al_process.redirect_error_to_same_as_output
				al_process.launch
			end
		end

	started_pids: TREE_MAP [INTEGER, STRING]
			-- Process IDs that might be running.
			-- KEY=CMD, VALUE=PID
		note
			warning: "[
				Processes are not gaurenteed to be running. This list
				represents processes that have been started and assigned
				a PID by the OS, but are not necessarily still running
				or that even started successfully.
				]"
		attribute
			create Result
		end

	last_pid: INTEGER
			-- PID of last process?

	taskkill_all_started_pids_by_force
			-- taskkill all on `started_pids'
		local
			l_list: ARRAYED_LIST [INTEGER]
		do
			l_list := started_pids.values
			across
				l_list as ic
			loop
				taskkill_all_by_force (ic.item)
			end
			started_pids.wipe_out
		ensure
			empty: started_pids.is_empty
		end

	taskkill_all_by_force (a_pid: INTEGER)
			-- taskkill /pid `a_pid' /t /f
		do
			taskkill (a_pid, True, True)
		end

	taskkill_by_image_name (a_name: STRING)
		do
			taskkill (tasklist.item (a_name).pid, True, True)
		end

	taskkill (a_pid: INTEGER; a_opt_t, a_opt_f: BOOLEAN)
			-- /t = Ends the specified process and any child processes started by it.
			-- /f = Specifies that processes be forcefully ended. This parameter
			--	is ignored for remote processes; all remote processes are forcefully ended.
		local
			l_cmd: STRING
		do
			l_cmd := "taskkill /pid"
			l_cmd.append_string_general (a_pid.out)
			if a_opt_t then
				l_cmd.append_string_general (" /t")
			end
			if a_opt_f then
				l_cmd.append_string_general (" /f")
			end
			process_command (l_cmd, Void)
			started_pids.remove_by_value (a_pid)
		end

	tasklist: TREE_MAP [TUPLE [image_name: STRING; pid: INTEGER; session_name: STRING; session_no, mem_usuage: INTEGER], STRING]
			-- Image Name                     PID Session Name        Session#    Mem Usage
			-- ========================= ======== ================ =========== ============
			--          1         2         3         4         5         6         7         8
			-- 12345678901234567890123456789012345678901234567890123456789012345678901234567890
			-- ^                       ^ ^      ^ ^              ^ ^         ^ ^          ^
			-- 1-25					     27-34    36-51            53-63       65-76
		local
			l_output, l_line, l_image_name, l_session_name: STRING
			l_list: LIST [STRING]
			i, l_pid, l_session, l_mem_usage: INTEGER
		do
			create Result
			l_output := output_of_command ("tasklist", Void)
			l_list := l_output.split ('%N')
			from
				i := 1
				l_list.start
			until
				l_list.off
			loop
				if i > 2 then
					l_line := l_list.item_for_iteration
					l_image_name := l_line.substring (1, 25)
					l_pid := l_line.substring (27, 34).to_integer
					l_session_name := l_line.substring (36, 51)
					l_session := l_line.substring (53, 63).to_integer
					l_mem_usage := l_line.substring (65, 76).to_integer
					Result.put ([l_image_name, l_pid, l_session_name, l_session, l_mem_usage], l_image_name)
				end
				l_list.forth
				i := i + 1
			end
		end

	output_of_command (a_command_line: READABLE_STRING_32; a_directory: detachable READABLE_STRING_32): STRING_32
                -- `output_of_command' `a_command_line' launched in `a_directory' (e.g. "." = Current directory).
		require
			cmd_not_empty: not a_command_line.is_empty
			dir_not_empty: attached a_directory as al_dir implies not al_dir.is_empty
		local
			l_buffer: SPECIAL [NATURAL_8]
			l_result: STRING_32
			l_args: ARRAY [STRING_32]
			l_cmd: STRING_32
			l_list: LIST [READABLE_STRING_32]
		do
			create Result.make_empty
			process_command (a_command_line, a_directory)
			if attached internal_process as al_process and then al_process.launched then
				from
					create l_buffer.make_filled (0, 512)
				until
					al_process.has_output_stream_closed or else al_process.has_output_stream_error
				loop
					l_buffer := l_buffer.aliased_resized_area_with_default (0, l_buffer.capacity)
					al_process.read_output_to_special (l_buffer)
					last_internal_result := converter.console_encoding_to_utf32 (console_encoding, create {STRING_8}.make_from_c_substring ($l_buffer, 1, l_buffer.count))
					if attached last_internal_result as al_result then
						al_result.prune_all ({CHARACTER_32} '%R')
						Result.append (al_result)
					end
				end
				if is_wait_for_exit then
					al_process.wait_for_exit
				end
			end
		end

	launch_fail_handler (a_result: STRING)
		do
			last_error_msg := a_result
		end

feature -- Status Report: Wait for Exit

	is_cli_hidden: BOOLEAN
			-- Will the CLI be hidden?

	is_cli_shown: BOOLEAN
			-- With the CLI be shown?
		do
			Result := not is_cli_hidden
		end

	is_not_wait_for_exit: BOOLEAN
			-- Do we not wait for process exit?

	is_wait_for_exit: BOOLEAN
			-- Do we wait for process exit?
		do
			Result := not is_not_wait_for_exit
		end

feature -- Settings

	set_hide_cli do is_cli_hidden := True end
	set_show_cli do is_cli_hidden := False end

	set_do_not_wait_for_exit
		do
			is_not_wait_for_exit := True
		end

	set_wait_for_exit
		do
			is_not_wait_for_exit := False
		end

feature {NONE} -- Code page conversion

	converter: LOCALIZED_PRINTER
			-- Converter of the input data into Unicode.
		once
			create Result
		end

	console_encoding: ENCODING
			-- Current console encoding.
		once
			Result := (create {SYSTEM_ENCODINGS}).console_encoding
		end

feature {TEST_SET_BRIDGE} -- Implementation: Constants

	DOS_where_not_found_message: STRING = "INFO: Could not find files for the given pattern(s).%N"

feature {TEST_SET_BRIDGE} -- Implementation

	internal_process: detachable BASE_PROCESS
			-- Ref to current process.

	last_internal_result: detachable STRING_32
			-- Ref to last result.

end
