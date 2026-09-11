# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# SecureDownloadPlugin is Copyright (C) 2014-2026 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::SecureDownloadPlugin;

=begin TML

---+ package Foswiki::Plugins::SecureDownloadPlugin

base class to hook into the foswiki core

=cut

use strict;
use warnings;

use Foswiki::Func ();

our $VERSION = '2.00';
our $RELEASE = '%$RELEASE%';
our $SHORTDESCRIPTION = 'Secure, temporary download links';
our $LICENSECODE = '%$LICENSECODE%';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean

initialize the plugin, automatically called during the core initialization process

=cut

sub initPlugin {

  unless ($Foswiki::cfg{SecureDownloadPlugin}{Secret}) {
    Foswiki::Func::writeWarning("SecureDownloadPlugin not properly configured: please specify a secret");
    return 0;
  }

  Foswiki::Func::registerTagHandler('SECURL', sub { return getCore()->SECURL(@_); });

  return 1;

}

=begin TML

---++ getCore() -> $core

returns a singleton Foswiki::Plugins::SecureDownloadPlugin::Core object for this plugin; a new core is allocated 
during each session request; once a core has been created it is destroyed during =finishPlugin()=

=cut

sub getCore {

  unless (defined $core) {
    require Foswiki::Plugins::SecureDownloadPlugin::Core;
    $core = Foswiki::Plugins::SecureDownloadPlugin::Core->new();
  }
  return $core;
}

=begin TML

---++ finishPlugin

finish the plugin and the core if it has been used,
automatically called during the core initialization process

=cut

sub finishPlugin {
  $core->finish() if $core;
  undef $core;
}

=begin TML

--++ dowload

entry point for the download cgi action. this is called via the switch board entry

=cut

sub download {
  return getCore()->download(@_);
}

1;
