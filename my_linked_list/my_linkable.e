note
	description: "Summary description for {MY_LINKABLE}."
	author: ""
	date: "$Date$"
	revision: "$Revision$"

class
	MY_LINKABLE [G]
create
	make
feature

	value: G
			-- the value stored in this cell

	set_value (new_value: G)
			-- assign the value stored in this cell
		do
			value := new_value
		ensure
			value = new_value
		end

	next: detachable MY_LINKABLE [G]
			-- the next cell in the list

	make (a_value: G)
			-- create this cell
		do
			value := a_value
		ensure
			value = a_value
		end

	link_to (other: detachable MY_LINKABLE [G])
			-- connect this cell to `other'
		do
			next := other
		ensure
			next = other
		end

	link_after (other: detachable MY_LINKABLE [G])
			-- insert this cell after `other' preserving what was after it
		require
			other /= Void
		do
			check attached other as o then
				link_to (o.next)
				o.link_to (Current)
			end
		ensure
			other /= Void
			other.next = Current
			attached other.next as on implies (on.next = old other.next)
		end

end
