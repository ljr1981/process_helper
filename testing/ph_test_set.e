note
	description: "[
		Eiffel tests that can be executed by testing tool.
	]"
	author: "EiffelStudio test wizard"
	date: "$Date$"
	revision: "$Revision$"
	testing: "type/manual"

class
	PH_TEST_SET

inherit
	TEST_SET_SUPPORT

feature -- Test routines

	process_test
			-- New test routine
		note
			testing:  "covers/{PH_PROCESS_HELPER}"
		local
			l_helper: PH_PROCESS_HELPER
		do
			create l_helper
			l_helper.started_pids.force (100, "x")
		end

end


