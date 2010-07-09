#!/usr/bin/perl

use FindBin '$Bin';
# This may need to adjusted in your case. 
use lib "$Bin/../../lib/";
use Smolder::Conf;
use Smolder::Dispatch;

#TODO: nope, can't use it here, it'll use the pre-init default for the location of the database :(
#use Smolder::DB;

use File::Path;

#don't know why these are not used in the right place..
use Smolder::AuthInfo;

# You will still need to set up dispatching in Apache
# following the general recipe in CGI::Application::Dispatch
# Possibly something like this:
# <Location />
#   RewriteEngine on
#   RewriteBase /
# 
#   # Handle the index page
#   RewriteRule ^home/smokebot/www/app$ /cgi-bin/dispatch.cgi [L,QSA]
# 
#   # If an actual file or directory is requested, serve directly
#   RewriteCond %{REQUEST_FILENAME} !-f
#   RewriteCond %{REQUEST_FILENAME} !-d
# 
#   # Otherwise, pass everything through to the dispatcher
#   RewriteRule ^home/smokebot/www/app/(.*)$ /cgi-bin/dispatch.cgi/$1 [L,QSA]
# </Location>

#TODO: erm, what about $ENV{SMOLDER_CONF}

my $confFile = "$Bin/smolder.conf";
if (-e $confFile ) {
	#conf file in cgi-bin
	Smolder::Conf->init_from_file($confFile);
} elsif (-e $ENV{HOME}.'/.smolder/smolder.conf' ) {
	#smolder.conf in users homedir - good for suexec hosting
	Smolder::Conf->init_from_file($confFile);
} else {
#TODO: er, sorry, needs to find a correct TMP - windows too
	#Default I'm trying smolder out case - use $HOME if its suexec, else fall back to /tmp
	my $smolderDir = ($ENV{HOME}||'/tmp').'/.smolder';
	mkpath($smolderDir);
	print STDERR "SMOLDER: Warning, running unconfigured, putting data into $smolderDir\n";
	mkpath($smolderDir.'/logs');
	mkpath($smolderDir.'/data');
	Smolder::Conf->init(
	#  Port                  => 80,
	#  HostName              => 'localhost',
	UrlPathPrefix           => '/smolder',
	#  FromAddress           => 'smokebot@yourdomain.com',
	#  SMTPHost              => 'smokebot.yourdomain.com',
	  LogFile               => $smolderDir.'/logs/app.log',
	  DataDir               => $smolderDir.'/data',
	);
}

#create or upgrade the database
require Smolder::DB;	#TODO: crap, have to delay the importing of Smolder::DB because the dbi string is set up globally
Smolder::DB->prepare_database;
Smolder::Dispatch->dispatch();
