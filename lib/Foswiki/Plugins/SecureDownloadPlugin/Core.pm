# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# SecureDownloadPlugin is Copyright (C) 2014-2018 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::SecureDownloadPlugin::Core;

use strict;
use warnings;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

use Foswiki::Func ();
use Digest::MD5 qw(md5_hex);
use File::MMagic ();

our $mimeTypeInfo;
our $mmagic;
use constant TRACE => 0; # toggle me

################################################################################
# static
sub writeDebug {
  return unless TRACE;
  #Foswiki::Func::writeDebug("SecureDownloadPlugin::Core - $_[0]");
  print STDERR "SecureDownloadPlugin - $_[0]\n";
}

################################################################################
# constructor
sub new {
  my $class = shift;

  my $this = bless({
    downloadArea => $Foswiki::cfg{SecureDownloadPlugin}{DownloadArea},
    secret => $Foswiki::cfg{SecureDownloadPlugin}{Secret},
    timeout => $Foswiki::cfg{SecureDownloadPlugin}{Timeout},
    @_
  }, $class);

  $this->{timeout} = 60 unless defined $this->{timeout};

  return $this;
}

################################################################################
# macro implementation
sub SECURL {
  my ($this, $session, $params, $topic, $web) = @_;

  writeDebug("called SECURL()");

  my $fileName = $params->{_DEFAULT};
  my ($downloadWeb, $downloadTopic) = Foswiki::Func::normalizeWebTopicName(undef, $this->{downloadArea});
  
  #timestamp
  my $t = time();
  my $t_hex = sprintf("%08x", $t);
  my $token = md5_hex($this->{secret}, $fileName, $t_hex);

  return Foswiki::Func::getScriptUrlPath().'/download/'.$token.'/'.$t_hex.$fileName;
}

################################################################################
# secure download service
sub download {
  my $this = shift;
  my $session = shift;
  my $request = $session->{request};
  my $response = $session->{response};

  my $pathInfo = $request->path_info;
  writeDebug("pathInfo=$pathInfo");

  my $token;
  my $t_hex;
  my $fileName;

  # check uri format
  if ($pathInfo =~ /^\/([a-f0-9]{32})\/([a-f0-9]{8})(.*)$/) {
    $token = $1;
    $t_hex = $2;
    $fileName = $3;
  } else {
    $response->status(403);
    $response->print("403 - access denied\n");
    return;
  }

  # check time
  my $t = hex($t_hex);

  writeDebug("token=$token, t_hex=$t_hex, t=$t, fileName=$fileName");

  if ($this->{timeout} && time() - $t > $this->{timeout}) {
    my $redirect = $Foswiki::cfg{SecureDownloadPlugin}{Redirect};
    if ($redirect) {
      unless ($redirect =~ /^http:/) {
        my ($web, $topic) = Foswiki::Func::normalizeWebTopicName(undef, $redirect);
        $redirect = Foswiki::Func::getScriptUrl($web, $topic, "view");
      }
      Foswiki::Func::redirectCgiQuery(undef, $redirect);
    } else {
      $response->status(410);
      $response->print("410 - gone");
    }
    return;
  }

  # check token
  my $thisToken = md5_hex($this->{secret}, $fileName, $t_hex);
  if ($thisToken ne $token) {
    $response->status(403);
    $response->print("403 - access denied\n");
    return;
  }

  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName(undef, $this->{downloadArea});
  my $topicObject = Foswiki::Meta->new($session, $web, $topic);

  # check download area exists
  unless ($topicObject->existsInStore()) {
    $response->status(404);
    $response->print("404 - download area does not exist\n");
    return;
  }

  # check file existence
  unless ($topicObject->hasAttachment($fileName)) {
    $response->status(404);
    $response->print("404 - $fileName does not exist\n");
    return;
  }

  # ok, now let's tell the web server to serve the file
  my $location = $Foswiki::cfg{SecureDownloadPlugin}{Location} 
    || $Foswiki::cfg{XSendFileContrib}{Location} 
    || $Foswiki::cfg{PubDir};

  my $headerName = $Foswiki::cfg{SecureDownloadPlugin}{XSendFileHeader} 
    || $Foswiki::cfg{XSendFileContrib}{Header} 
    || 'X-LIGHTTPD-send-file';

  my $fileLocation = $location.'/'.$web.'/'.$topic.'/'.$fileName;
  my $filePath = $Foswiki::cfg{PubDir}.'/'.$web.'/'.$topic.'/'.$fileName;

  my @stat = stat($filePath);
  my $lastModified = Foswiki::Time::formatTime($stat[9] || $stat[10] || 0, '$http', 'gmtime');
  my $ifModifiedSince = $request->header('If-Modified-Since') || '';

  writeDebug("filePath=$filePath, fileLocation=$fileLocation");
  writeDebug("lastModified=$lastModified, ifModifiedSince=$ifModifiedSince");

  my $dispositionMode = $Foswiki::cfg{SecureDownloadPlugin}{Disposition} || 'redirect';

  if ($lastModified eq $ifModifiedSince) {
    $response->header(
      -status => 304,
    );
  } else {
    $response->header(
      -status => 200,
      -type => mimeTypeOfFile($filePath),
      -content_disposition => "$dispositionMode; filename=\"$fileName\"",
      $headerName => $fileLocation,
    );
  }

  return;
}

################################################################################
sub mimeTypeOfFile {
  my $fileName = shift;

  my $mimeType;
  if ($fileName && $fileName =~ /\.([^.]+)$/) {
    my $suffix = $1;

    $mimeTypeInfo = Foswiki::Func::readFile($Foswiki::cfg{MimeTypesFileName}) 
      unless defined $mimeTypeInfo;

    if ($mimeTypeInfo =~ /^([^#]\S*).*?\s$suffix(?:\s|$)/im) {
      $mimeType = $1;
      writeDebug("mimetypes file says $mimeType to $fileName");
      return $mimeType;
    }
  }

  $mmagic = File::MMagic->new() unless defined $mmagic;

  $mimeType = $mmagic->checktype_filename($fileName);

  if (defined $mimeType && $mimeType ne "x-system/x-error") {
    writeDebug("mmagic says $mimeType to $fileName");
    return $mimeType;
  }

  writeDebug("unknown mime type of $fileName");

  return 'application/octet-stream';
}

1;
