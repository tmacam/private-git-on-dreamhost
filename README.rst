

=======================================
Private GIT repositories (on DreamHost)
=======================================

:Author: Tiago Alves Macambira
:Licence: Creative Commons By-SA


.. contents:: Table of Contents



Introduction
============

This is *yet another* guide describing how to setup private
HTTP-accessible Git repositories on Dreamhost_ using Git's
``git-http-backend`` (a.k.a git's `Smart HTTP protocol`__). While
similar guides can easily be found by the thousands in the Web (I've
listed some of them in the Refereces section), I've found that some
guides have outdated information or that the setup described in
them could be improved. Thus, this guide tries to update, improve and
consolidate the information dispersed in such sources.

__ GitSmartHTTP_

Some might ask "Why on Earth would someone opt to create its own
private Git hosting solution while better offerings are available from
sites such as, let's say, GitHub_?" As the guy `from RailsTips
pointed out in one of his articles`__, sometimes you don't need or
don't want to "share" a project with anyone but yourself and
paying for a GitHub_-like service might just not make sense.  If
that's your case, than this guide is for you.

__ RailsTipsArticle_

While aimed at a Dreamhost_-hosted accounts and the environment such
accounts have as of 2010-10-17, I believe the process described here
can be used in other hosting providers as well.


It is important to highlight that one of the objectives of this guide
is to describe a process that:

* should be easy to perform by just renaming or editing this guide's
  companion files and
* once complete, can be easily be reused to generate other "collection
  of repositories", with different URLs and passwords.


Assumptions and requirements
----------------------------

* No WebDav or SSH support is needed nor used for serving Git repositories.
  
  Once again, the focus is on HTTP access using
  ``git-http-backend``. As for SSH, guides describing how to setup a
  similar environment for SSH-accessible repositories can be found
  easily on the web.

* Repositories will be password protected and available for both
  reading and writting.

  As we will explain latter, in the `Setup git-http-backend for your
  repositories`_ section, we will have to password-protect our
  repositories in order to be able to ``git push`` to them through HTTP.

* We will stick to a DRY_ (Don't Repeat Yourself) philosophy.

  Thus, we want configuration options to be repeated in as few places
  as possible. We will use environment variables in Apache
  configuration files to do this. If this makes you uncomfortable,
  well, you can always manually spread configuration options all over
  the place. :-) Your call.


* The web server being used is Apache.

  Well, that is what Dreamhost_ allows me to use so that is going to
  be the focus of this guide. While it should not be that difficult to
  port the settings here to something suitable for another web server,
  describing how to do it is out of the scope of this guide.

* We are able to run CGI scripts.

  `DreamHosts puts some restrictions`__
  on how a CGI script can be executed and the environment where it
  runs. We will abide to those restrictions.

__ DreamHostWikiCGI_

* ``ScriptAlias`` is not allowed by the web server.

  The instructions given in git-http-backend_ manpage will not work as
  they use ``ScriptAlias``. The idea is to use common CGI scripts and
  ``mod_rewrite`` instead, roughly following the ideas presented in
  http://wiki.dreamhost.com/Git#Smart_HTTP .

* SuExec_ is used to run CGI scripts.

  Notice that, as stated in DreamHost page on CGI, ``SuExec`` "*wipes out all
  environment variables that don't start with HTTP\_"*. All our
  env. vars. will have this prefix.

* Your private git repositories will be accessible in a subpath of your
  domain.

  The idea is that your private git repos will be available in an
  address such as **http://www.example.tld/corporate-git/**. Adapting
  the instructions bellow so you can serve them from the root of a
  domain of its own, say **http://corporate-git.example.tld** should
  be fairly simple.

About this document
-------------------

This document and its companion files are initially hosted on
http://github.com/tmacam/private-git-on-dreamhost.

The file ``README.rst`` is generated from ``README-real.rst``.  So, if
you plan on doing any updates or fixes, ``README-real.rst`` is the
file you ought to edit. Just run ``make`` afterwards in order to get
``README.rst`` updated as well. This is done because I wanted to use
GitHub_'s automatic rendering of README files but I didn't want to
just paste the contents of the companion files in this ``README.rst``
and risk getting the Guide and files out of sync.  Unfortunately,
GitHub does not allow the use of RestructuredText's ``include``
directive, so I had to fake it -- and here is the reason why we have
``README-real.rst``.

This guide is distributed under the Creative Common BY-SA license while
companion files are distributed under a MIT License.


Installation
============

All the commands and instructions given bellow should be performed on
the machine in Dreamhost where your account is installed. So ssh to it
and let's start.

Install Git
-----------

Well, this should probably be a non-issue since git comes
pre-installed on most Dreamhost machines. To verify it::

    $ git --version
    git version 1.7.1.1

As you see, the box that serves my domain in dreamhost has git version
1.7.1.1 installed. `Anything greater than 1.6.6 shall do`__.

__ GitSmartHTTP_



If you don't have git installed in you box, have an old version or if
for some other reason your need to compile git, follow Craig's instructions in
|CraigJolicoerArticle|_.



Create the directory where your repositories will live
------------------------------------------------------


It should reside somewhere not accessible from the web or directly
served by the web server. We will tell Apache and ``git-http-backend``
how to properly and securely serve those repositories latter. For now,
we want them protected from third parties.

Say we decided to store them in ``~/private_repos/``. We will refer to
this directly by ``GIT_REPOS_ROOT`` in the rest of this guide. Create
this directory and protect it against filesystem access from others::

    export GIT_REPOS_ROOT="~/private_repos/"
    mkdir ${GIT_REPOS_ROOT}
    chmod 711 ${GIT_REPOS_ROOT}


Setup the bare repository creation script
-----------------------------------------



We will use the script ``newgit.sh``, presented bellow, to create new
repositories [1]_ [2]_ . Remember to modify
the value of the GIT_REPOS_ROOT variable in it to match our setup:

::


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

Move or copy this file to an appropriate path (say, your home
directory would be fine) and turn it into an executable::

    chmod u+x ~/newgit.sh

.. [1] This script is based in http://gist.github.com/73622

.. [2] Other guides prefer to use something similar wrapped as a Bash
       function but I'd rather have it as a script


Apache Setup
------------

Now, let's configure Apache to securely serve those repositories.


Setup your .htaccess
~~~~~~~~~~~~~~~~~~~~

As we stated in `Assumptions and requirements`_, we want to serve our files from
**http://www.example.tld/corporate-git/**. So, go to the directory
holding your domain files (``~/www.example.tld``, in our exemple),
create a ``corporate-git`` directory in it if it doesn't exist yet and create
a ``.htaccess`` file in it::

    cd ~/www.example.tld
    mkdir corporate-git
    cd corporate-git
    export GIT_WEB_DIR=`pwd` # we will use it in latter steps
    touch .htaccess
    chmod 644 .htaccess


Now, edit this ``.htaccess`` contents to match the text presented
bellow or just copy the contents of the file ``model-htaccess`` into
it and adapt it to match your config:


::


    Options +Indexes
    
    # GIT BEGIN ###########################################################
    
    SetEnv HTTP_GIT_PROJECT_ROOT /home/user/private_repos/
    SetEnv HTTP_GITWEB_CONFIG /home/user/private_repos/gitweb_config.perl
    
    
    RewriteEngine On
    DirectoryIndex  gitweb_wrapper.cgi
    # The following two rules can be used instead of DirectoryIndex
    #RewriteRule ^$  gitweb_wrapper.cgi/ [L,E=SCRIPT_URL:/$1]
    #RewriteRule ^([?].*)$ gitweb_wrapper.cgi/ [L,E=SCRIPT_URL:/$1]
    
    # Everything else that is not a file is forwarded to git-http-backend
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^([^?].+)$ git-http-backend-private.cgi/$1
    
    
    # GIT END ############################################################
    
    # AUTHENTICATION BEGIN ###############################################
    AuthType Digest
    AuthName "Private Git Repository Access"
    # UNCOMMENT THE LINE BELLOW FOR BETTER PERFORMANCE
    # AuthDigestDomain /corporate-git/
    AuthUserFile /home/user/private_repos/.htpasswd
    Require valid-user
    # AUTHENTICATION END  ################################################

For now we will focus on the area between the ``# GIT BEGIN`` and ``#
GIT END`` blocks.  Modify ``HTTP_GIT_PROJECT_ROOT`` to match you setup:
it should point to the **full path** where you store your private
repositories. Just expand the value of ``GIT_REPOS_ROOT`` to get this
information::

    $ (cd ${GIT_REPOS_ROOT}; pwd)
    /home/user/private_repos/

So, in our example, ``HTTP_GIT_PROJECT_ROOT`` value should be set to
``/home/user/private_repos/``, as presented in the example above.

Setup git-http-backend for your repositories
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Not we will create a CGI script that will invoke
``git-http-backend``. In your ``.htaccess`` this script is referred as
``git-http-backend-private.cgi``. Create it in the same directory
where you ``.htaccess`` is by coping the one that comes with this guide
to that directory or by creating an empty file with the following
contents:

::


    #!/bin/sh
    export GIT_HTTP_EXPORT_ALL=1
    export GIT_PROJECT_ROOT=${HTTP_GIT_PROJECT_ROOT:?HTTP_GIT_PROJECT_ROOT env. variable not set. Aborting.}
    /usr/lib/git-core/git-http-backend

Turn it into an executable file::

    chmod 755 git-http-backend-private.cgi


.. attention::
    You may need to update the path to ``git-http-backend`` executable
    if git was installed in a non-default location.

And that's it. No need to setup anything: all the settings this
scripts are passed to it through environment variables set by Apache
and defined in the ``.htaccess`` file.

From this point on you should be able to create repositories from the
command line and
access them through HTTP, but they will be
**read-only**. As stated in git-http-backend_ manpage, "*by default,
only the ``upload-pack`` service is enabled, which serves git ``fetch-pack``
and git ls-remote clients, which are invoked from ``git fetch``, ``git pull``,
and ``git clone``*". For **write access**, i.e., to be able to perform a
``git push``, the ``receive-pack`` service is needed, and it **is only
enabled when the client is authenticated**.


Password-protect your repository
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We are almost set. Let's configure password protection for this whole
thing.  We will focus on the latter part of your ``.htaccess``, the one
between ``# AUTHENTICATION BEGIN`` and ``# AUTHENTICATION END`` that we
reproduce bellow::

    # AUTHENTICATION BEGIN ########################
    AuthType Digest
    AuthName "Private Git Repository Access"
    AuthUserFile /home/user/private_repos/.htpasswd
    Require valid-user
    # AUTHENTICATION END  #########################

You will have to create the password file pointed by ``AuthUserFile``
and use the ``htdigest`` tool to add a user to this file ::

    touch /home/user/private_repos/.htpasswd
    htdigest /home/user/private_repos/.htpasswd "Private Git Repository Access" username


You will be prompted for a password. And that's it.


Notice:

* we are using `Digest Authentication
  <http://httpd.apache.org/docs/2.2/mod/mod_auth_digest.html#using>`_. It
  is supposed to be more secure than plain authentication.
* The password file should be keep in a place not directly accessible
  from the web. Ideally it should not even be placed in the directory
  to be served by ``git-http-backend`` but I'm lazy and I hope this
  will be enough. :) 
* If you update the value of the ``AuthName`` setting you **must**
  also change the 2nd. parameter passed to ``htdigest``, i.e., the
  *Realm*, as `they must match
  <http://www.freebsdwiki.net/index.php/Apache,_Digest_Authentication>`_!
  Odd, I know. But that's the way it is.


Setup GitWeb
~~~~~~~~~~~~

If you followed this guide up to this point than you are able to use
your repositories with git with no major issues. But you will not be
able to browse them with a web browser, retrieve the list of
repositories you have, see diffs, commit messages nor nothing like
that. To make things better, let's install GitWeb, another CGI
interface that will provide a web interface that allows to do all
those things I just said you couldn't.

.. note::
   Most of the content in this section comes from  Kang's |KangArticle|_.


Retrieving and installing
+++++++++++++++++++++++++

GitWeb comes in the same source package as git itself. Unfortunately,
Dreamhost doesn't install it by default so we will have to install it
manually ourselves. Do your remember what is your git version? No?
Find it all::

    git --version

Go to `git homepage`_ and download the corresponding source
package. In my example, in which my git version is 1.7.1.1, I would
need to grab the ``git-1.7.1.1.tar.gz`` source package::

    cd ~ # Yep, we will download it in our home directory
    wget http://www.kernel.org/pub/software/scm/git/git-1.7.1.1.tar.gz

Unpack it, build GitWeb::

    tar zxvf git-1.7.1.1.tar.gz
    cd git-1.7.1.1
    make prefix=/usr/bin gitweb/gitweb.cgi
    rm gitweb/gitweb.perl # we won't need it

We will install it into ``~/gitweb/``::

   export GITWEB_INSTALL_DIR="~/gitweb"
   cp -r gitweb ${GITWEB_INSTALL_DIR}

We are almost there.


Setting up GitWeb
+++++++++++++++++

Now, copy all the GitWeb's media files into the directory
where your ``.htaccess`` is::

    cp ${GITWEB_INSTALL_DIR}/*.{css,png,js} ${GIT_WEB_DIR}
    # in this example, GIT_WEB_DIR points
    # to ~/www.example.tld/corporate-git

Get back to where your ``.htaccess`` file is
(i.e. ``GIT_WEB_DIR``). We will create a wrapper CGI for
GitWeb. Just copy ``gitweb_wrapper.cgi`` or create an empty file with
the contents bellow:

::


    #!/bin/bash
    export GITWEB_CONFIG=${HTTP_GITWEB_CONFIG:?HTTP_GITWEB_CONFIG env. variable not set. Aborting.}
    export GIT_PROJECT_ROOT=${HTTP_GIT_PROJECT_ROOT:?HTTP_GIT_PROJECT_ROOT env. variable not set. Aborting.}
    
    ${HOME}/gitweb/gitweb.cgi

Turn it into an executable file::

    chmod 755 gitweb_wrapper.cgi


.. attention::
   If you have installed gitweb files in a different directory, you
   will have to update this file to match the install location.

Once again, we are using settings stored in ``.htaccess`` file and
passing them to a script using environment variables set by Apache. In
this case, we are informing the wrapper script where our repositories
are with ``HTTP_GIT_PROJECT_ROOT``, and informing it where GitWeb
configuration file is with ``HTTP_GITWEB_CONFIG``. The wrapper script,
in turn, will forward these informations to both GitWeb and to its
config file.

Now, let's create GitWeb configuration file. Just
copy ``gitweb_config.perl`` provided with this guide to
``${GIT_REPOS_ROOT}/gitweb_config.perl`` or create an empty file in
that path location with the following contents:

::


    # where is the git binary?
    $GIT = "/usr/bin/git";
    # where are our git project repositories?
    $projectroot = $ENV{'GIT_PROJECT_ROOT'};
    # what do we call our projects in the gitweb UI?
    $home_link_str = "My Git Projects";
    #  where are the files we need for gitweb to display?
    @stylesheets = ("gitweb.css");
    $logo = "git-logo.png";
    $favicon = "/favicon.png";
    # what do we call this site?
    $site_name = "My Personal Git Repositories";

You can customize it a little bit, if you want, but the most important
setting, ``$projectroot``, is set to match the value of
``HTTP_GIT_PROJECT_ROOT``, a env. var. set by Apache.

Notice that this file, ``gitweb_config.perl`` is stored in the same
directory where your repositories are, in ``${GIT_REPOS_ROOT}``. If,
for some reason, you prefer to store it elsewhere, you will have to
update this information in the ``.htaccess`` file.

    

Troubleshooting
---------------

So, something is not working as expected?

Disable authentication
~~~~~~~~~~~~~~~~~~~~~~

Comment out the authentication code. This will ease your "debugging"
process.

Remember to uncomment it latter.

Use info.cgi script to check CGI script's environment
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A nice way to check if there is something really wrong with your setup
is to use the ``info.cgi``, whose code is presented bellow. This
script is only a minor modification to the one presented in `Dreamhost
wiki page on CGI`__ and allows your to do verify if you are able to
execute CGI scrips and what settings Apache is passing to the other
CGI scripts we use here.

::


    #!/bin/sh
    
    # disable filename globbing
    set -f
    
    echo "Content-type: text/plain; charset=iso-8859-1"
    echo
    
    echo CGI/1.0 test script report:
    echo
    
    echo argc is $#. argv is "$*".
    echo
    
    echo SERVER_SOFTWARE = $SERVER_SOFTWARE
    echo SERVER_NAME = $SERVER_NAME
    echo GATEWAY_INTERFACE = $GATEWAY_INTERFACE
    echo SERVER_PROTOCOL = $SERVER_PROTOCOL
    echo SERVER_PORT = $SERVER_PORT
    echo REQUEST_METHOD = $REQUEST_METHOD
    echo HTTP_ACCEPT = "$HTTP_ACCEPT"
    echo PATH_INFO = "$PATH_INFO"
    echo PATH_TRANSLATED = "$PATH_TRANSLATED"
    echo SCRIPT_NAME = "$SCRIPT_NAME"
    echo QUERY_STRING = "$QUERY_STRING"
    echo REMOTE_HOST = $REMOTE_HOST
    echo REMOTE_ADDR = $REMOTE_ADDR
    echo REMOTE_USER = $REMOTE_USER
    echo AUTH_TYPE = $AUTH_TYPE
    echo CONTENT_TYPE = $CONTENT_TYPE
    echo CONTENT_LENGTH = $CONTENT_LENGTH
    echo ""
    echo HTTP_GIT_PROJECT_ROOT = $HTTP_GIT_PROJECT_ROOT
    echo HTTP_GITWEB_CONFIG = $HTTP_GITWEB_CONFIG
    
    exit 0
    

Copy it to ``GIT_WEB_DIR``, turn it into an executable script
(``chmod 755 ...``) and point your browser to it ( That would be
``http://www.example.tld/corporate-git/`` in our example).


__ DreamHostWikiCGI_

Check the server logs
~~~~~~~~~~~~~~~~~~~~~

We are listing this as a last step but that's probably the fist place
where you should have looked for clues: your server logs. 


For example::

    [Mon Oct 25 18:30:28 2010] [error] [client 150.164.3.192] Service not enabled: 'receive-pack'

This message says that 'receive-pack' was not enable -- probably
because you are trying to push to a repository and authentication was
disabled. As we explained in `Setup git-http-backend for your
repositories`_, you **must** use authentication to be able to write
(*push*) to repositories using git-http-backend.


This one should be pretty obvious::

    Digest: user username: password mismatch: /corporate-git/test.git/info/refs

And so on... 



Usage
=====

So everything is ready to use. How do you actually create and use
these new repositories?

Creating new bare repositories
------------------------------

In order to create a new repository, say ``toyproject.git``, all you
have to do is ssh into your Dreamhost account and::

    ~/newgit.sh -r ${GIT_REPOS_ROOT} -d "My first private repository" -n toyproject


That's it: your created and empty repository in you repository
collection. You can *clone* it if you want. 


Cloning an empty repository
---------------------------

So, you got a new pristine and empty repository. Let's *clone* it, shall we?::


    $ git clone http://username@www.example.tld/corporate-git/toyproject.git
    Initialized empty Git repository in /private/tmp/teste/.git/
    Password: 
    warning: You appear to have cloned an empty repository.


.. important::
    Have you noticed that we have a ``username@`` in the URL? This
    tells git that it must athenticate to the server before trying to
    access the git repository.
    
    In this example, we are acessing the
    repository with the crentials of the user ``username``, the one we
    setup in `Password-protect your repository`_. Modify it to match
    the user you created in that step.

But what if you already have a local repository and all you want is
push it and its history to the server?

Pushing to a new empty repository
---------------------------------

What you usually do is creating a local repository, adding file to it and committing this repository history to the new, empty and pristine repository in your web server::

    mkdir toyproject
    cd toyproject
    git init
    touch README
    git add README
    git commit -m 'first commit'
    git remote add origin http://username@www.example.tld/corporate-git/toyproject.git
    git push origin master
      
If you have an existing Git Repo, that's the procedure::

    cd existing_toyproject_git_repo
    git remote add origin http://username@www.example.tld/corporate-git/toyproject.git
    git push origin master
      
The above workflow follows what is presented in http://help.github.com/creating-a-repo/.



Final remarks
=============

If you need more than one collection of private repositories (say, one
for you and one to share privately with a group of coworkers), all you
need to do is:

 1. Create a directory for each of these collections.
 2. Create copies of ``newgit.sh``, one for each collection, and setup
    the value of GIT_REPOS_ROOT in each of them.
 3. Adapt each .htaccess accordingly.
 4. GitWeb: copy its files too.. Or just sym-link it from a pristine copy.
 

TODOs
=====

* Focus on reusability.
* Write the `Final remarks`_ section properly.


http://httpd.apache.org/docs/2.2/mod/mod_rewrite.html#rewritecond --
serve directly w/ apache if...

Adding project .description directly in the scripts



References
==========

* arvinderkang.com - |KangArticle|_
* craigjolicoeur.com - |CraigJolicoerArticle|_
* |RailsTipsArticle|_
* http://faves.eapen.in/guide-to-hosting-git-repositories-on-dreamhos
* http://gist.github.com/73622
* http://wiki.dreamhost.com/Git#Smart_HTTP
* http://arvinderkang.com/2010/08/25/hosting-git-repositories-on-dreamhost/
* git-http-backend_ manpage
* |GitSmartHTTP|_
* http://www.jedi.be/blog/2009/05/06/8-ways-to-share-your-git-repository/
* http://help.github.com/creating-a-repo/


.. _DreamHost: http://www.dreamhost.com
.. _GitHub: http://github.com
.. |RailsTipsArticle| replace:: Git'n Your Shared Host On
.. _RailsTipsArticle: http://railstips.org/blog/archives/2008/11/23/gitn-your-shared-host-on/
.. |CraigJolicoerArticle| replace:: Hosting Git Repositories on Dreamhost
.. _CraigJolicoerArticle: http://craigjolicoeur.com/blog/hosting-git-repositories-on-dreamhost
.. |KangArticle| replace:: Hosting Git repositories on Dreamhost
.. _KangArticle: http://arvinderkang.com/2010/08/25/hosting-git-repositories-on-dreamhost/
.. _SuExec: http://wiki.dreamhost.com/Suexec
.. _DRY: http://en.wikipedia.org/wiki/Don't_repeat_yourself
.. _git-http-backend: http://www.kernel.org/pub/software/scm/git/docs/git-http-backend.html
.. |GitSmartHTTP| replace:: Pro Git - Smart HTTP Transport
.. _GitSmartHTTP: http://progit.org/2010/03/04/smart-http.html
.. _Git homepage: http://git-scm.com/
.. _DreamHostWikiCGI: http://wiki.dreamhost.com/CGI
.. 
   .. target-notes::


.. sectnum::
