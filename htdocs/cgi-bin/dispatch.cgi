#!/usr/bin/perl

use FindBin '$Bin';
# This may need to adjusted in your case. 
use lib "$Bin/../../lib/;
use Smolder::Conf;
use Smolder::Dispatch;

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

# See the docs in lib/Smolder/Conf.pm for possible values here.
Smolder::Conf->init(
#  Port                  => 80,
#  HostName              => 'smokebot.yourdomain.com',
#  FromAddress           => 'smokebot@yourdomain.com',
#  SMTPHost              => 'smokebot.yourdomain.com',
#  LogFile               => '/home/smokebot/logs/app.log',
#  DataDir               => '/home/smokebot/data',
);
Smolder::Dispatch->dispatch();
