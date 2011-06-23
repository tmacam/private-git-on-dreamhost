#!/bin/bash
export GITWEB_CONFIG=${HTTP_GITWEB_CONFIG:?HTTP_GITWEB_CONFIG env. variable not set. Aborting.}
export GIT_PROJECT_ROOT=${HTTP_GIT_PROJECT_ROOT:?HTTP_GIT_PROJECT_ROOT env. variable not set. Aborting.}

# Replace "/home/user/gitweb/" for the correct path to where
# gitweb.cgi was installed.

/home/user/gitweb/gitweb.cgi
