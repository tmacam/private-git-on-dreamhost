#!/bin/sh
export GIT_HTTP_EXPORT_ALL=1
export GIT_PROJECT_ROOT=${HTTP_GIT_PROJECT_ROOT:?HTTP_GIT_PROJECT_ROOT env. variable not set. Aborting.}
/usr/lib/git-core/git-http-backend
