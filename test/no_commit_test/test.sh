#!/bin/bash
git status
sha1=`git rev-parse HEAD`

/home/git-octopus.sh -n features/*

#should be back to HEAD
if [[ `git rev-parse HEAD` != $sha1 ]] ; then
	exit 1
fi

#repository should be clean
if [[ -n `git diff-index HEAD` ]] ; then
	exit 1
fi