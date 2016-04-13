# Copyright (c) 2005 Junio C Hamano
#
# Resolve two or more trees.
#

merge-octopus-fork () { 
	# The first parameters up to -- are merge bases; the rest are heads.
	bases= head= remotes= sep_seen=
	for arg
	do
		case ",$sep_seen,$head,$arg," in
		*,--,)
			sep_seen=yes
			;;
		,yes,,*)
			head=$arg
			;;
		,yes,*)
			remotes="$remotes$arg "
			;;
		*)
			bases="$bases$arg "
			;;
		esac
	done

	# MRC is the current "merge reference commit"
	# MRT is the current "merge result tree"

	MRC=$(git rev-parse --verify -q $head)
	MRT=$(git write-tree)
	NON_FF_MERGE=0
	OCTOPUS_FAILURE=0
	for SHA1 in $remotes
	do
		case "$OCTOPUS_FAILURE" in
		1)
			# We allow only last one to have a hand-resolvable
			# conflicts.  Last round failed and we still had
			# a head to merge.
			echo "Automated merge did not work."
			echo "Should not be doing an Octopus."
			return 2
		esac

		eval pretty_name=\${GITHEAD_$SHA1:-$SHA1}
		if test "$SHA1" = "$pretty_name"
		then
			SHA1_UP="$(echo "$SHA1" | tr a-z A-Z)"
			eval pretty_name=\${GITHEAD_$SHA1_UP:-$pretty_name}
		fi
		common=$(git merge-base --all $SHA1 $MRC) ||
			die "Unable to find common commit with $pretty_name"

		case "$LF$common$LF" in
		*"$LF$SHA1$LF"*)
			echo "Already up-to-date with $pretty_name"
			continue
			;;
		esac

		if test "$common,$NON_FF_MERGE" = "$MRC,0"
		then
			# The first head being merged was a fast-forward.
			# Advance MRC to the head being merged, and use that
			# tree as the intermediate result of the merge.
			# We still need to count this as part of the parent set.

			echo "Fast-forwarding to: $pretty_name"
			git read-tree -u -m $head $SHA1 || return 0
			MRC=$SHA1 MRT=$(git write-tree)
			continue
		fi

		NON_FF_MERGE=1

		echo "Trying simple merge with $pretty_name"
		git read-tree -u -m --aggressive  $common $MRT $SHA1 || return 2
		next=$(git write-tree 2>/dev/null)
		if test $? -ne 0
		then
			echo "Simple merge did not work, trying automatic merge."
			git merge-index -o git-merge-one-file -a

			if test $? -ne 0
			then
				git apply-conflict-resolution || OCTOPUS_FAILURE=1
			fi

			next=$(git write-tree 2>/dev/null)
		fi

		MRC="$MRC $SHA1"
		MRT=$next
	done

	return "$OCTOPUS_FAILURE"
}
