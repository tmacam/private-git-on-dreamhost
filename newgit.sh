#!/bin/bash

# this script is based on code from the following blog post
# http://arvinderkang.com/2010/08/25/hosting-git-repositories-on-dreamhost/
# and http://gist.github.com/73622


set -e


# Please, configure a default GIT_REPOS_ROOT to match your config
#GIT_REPOS_ROOT="~/private_repos/"

DEFAULT_DESCRIPTION='no description :('


# describe how the script works
usage()
{
  echo "Usage: $0 [ -h ] [ -r directory] [ -d description ] [ -n projectname ]"
  echo ""
  echo "If no projectname is given, the name of the parent folder will be used as project name."
  echo ""
  echo "  -r directory   : (root) directory holding your git repositories"
  echo "  -d description : description for gitweb"
  echo "  -h             : print this screen"
  echo "  -n name        : name of the project (should end in .git)"
  echo ""
}

DESCRIPTION=${DEFAULT_DESCRIPTION}

# evaluate the options passed on the command line
while getopts r:d:n:h option
do
  case "${option}"
  in
    r) GIT_REPOS_ROOT=${OPTARG};;
    d) DESCRIPTION=${OPTARG};;
    n) REPONAME=${OPTARG};;
    h) usage
      exit 1;;
  esac
done

# check if repositories directory is given and is accessible
if [ -z $GIT_REPOS_ROOT  ]; then
	usage
	exit 1
fi
if ! [ -d $GIT_REPOS_ROOT  ]; then
	echo "ERROR: '${GIT_REPOS_ROOT}' is not a directory"
	echo ""
	usage
	exit 1
fi


# check if name of repository is given. if not, use folder name
if [ -z $REPONAME ]; then
  REPONAME=$(basename $PWD)
fi

# Add .git at and if needed
if ! ( echo $REPONAME | grep -q '\.git$'); then
  REPONAME="${REPONAME}.git"
fi


#
# Ready to go
#


REP_DIR="${GIT_REPOS_ROOT}/${REPONAME}"
echo REP_DIR $REP_DIR DESCRIPTION '[' ${DESCRIPTION} ']'
exit 0
mkdir ${REP_DIR}
pushd ${REP_DIR}
git --bare init
git --bare update-server-info
cp hooks/post-update.sample hooks/post-update
chmod a+x hooks/post-update
echo $DESCRIPTION > description
# This mark the repository as exportable.
# For more info refer to git-http-backend manpage
touch git-daemon-export-ok
popd
exit 0
