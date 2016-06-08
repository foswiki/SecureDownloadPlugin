# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# SecureDownloadPlugin is Copyright (C) 2014-2016 Michael Daum http://michaeldaumconsulting.com
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

use strict;
use warnings;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

use Foswiki::Func ();

our $VERSION = '1.00';
our $RELEASE = '08 Jun 2016';
our $SHORTDESCRIPTION = 'Secure, temporary download links';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

sub initPlugin {
  Foswiki::Func::registerTagHandler('SECURL', sub { return getCore()->SECURL(@_); });

  unless ($Foswiki::cfg{SecureDownloadPlugin}{Secret}) {
    Foswiki::Func::writeWarning("SecureDownloadPlugin not properly configured: please specify a secret");
    return 0;
  }

  return 1;

}

sub getCore {

  unless (defined $core) {
    require Foswiki::Plugins::SecureDownloadPlugin::Core;
    $core = Foswiki::Plugins::SecureDownloadPlugin::Core->new();
  }
  return $core;
}

sub finishPlugin {
  undef $core;
}

sub download {
  return getCore()->download(@_);
}

1;
