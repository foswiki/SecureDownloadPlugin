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

package Foswiki::Plugins::SecureDownloadPlugin::Core;

=begin TML

---+ package Foswiki::Plugins::SecureDownloadPlugin::Core

core class for this plugin

an singleton instance is allocated on demand

=cut

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

use constant TRACE => 0; 

# static

=begin TML

---++ ClassMethod new() -> $core

constructor for a Core object

=cut

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

sub finish {
  my $this = shift;

  undef $this->{_mmagic};
  undef $this->{_mimeTypeInfo};
}

=begin TML

---++ ObjectMethod SECURL() 

implements the %SECURL macro

=cut

sub SECURL {
  my ($this, $session, $params, $topic, $web) = @_;


  _writeDebug("called SECURL()");
  $web = $params->{web} if defined $params->{web};
  $web = undef if $web eq 'default';

  my $fileName = $params->{_DEFAULT};
  my $t = time();
  my $t_hex = sprintf("%08x", $t);
  my $token = md5_hex($this->{secret}, $fileName, $t_hex);

  return Foswiki::Func::getScriptUrlPath($web, undef, "download").'/'.$token.'/'.$t_hex.$fileName;
}

=begin TML

---++ ObjectMethod download

secure download service

=cut

sub download {
  my $this = shift;
  my $session = shift;
  my $request = $session->{request};
  my $response = $session->{response};

  my $pathInfo = $request->path_info;
  _writeDebug("pathInfo=$pathInfo");

  my $token;
  my $t_hex;
  my $fileName;
  my $downloadWeb;

  # (1) check uri format
  if ($pathInfo =~ /^\/([a-f0-9]{32})\/([a-f0-9]{8})(.*)$/) {
    $token = $1;
    $t_hex = $2;
    $fileName = $3;
  } elsif ($pathInfo =~ /^\/($Foswiki::regex{webNameRegex})\/([a-f0-9]{32})\/([a-f0-9]{8})(.*)$/) {
    $downloadWeb = $1;
    $token = $2;
    $t_hex = $3;
    $fileName = $4;
  } else {
    $response->status(403);
    $response->print("403 - access denied\n");
    return;
  }

  # (2) check time
  my $t = hex($t_hex);

  _writeDebug("token=$token, t_hex=$t_hex, t=$t, fileName=$fileName");

  if ($this->{timeout} && time() - $t > $this->{timeout}) {
    my $redirect = $Foswiki::cfg{SecureDownloadPlugin}{Redirect};
    if ($redirect) {
      unless ($redirect =~ /^https?:/) {
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

  # (3) check token
  my $thisToken = md5_hex($this->{secret}, $fileName, $t_hex);
  if ($thisToken ne $token) {
    $response->status(403);
    $response->print("403 - access denied\n");
    return;
  }

  my $downloadTopic;

  if ($downloadWeb) {
    $downloadTopic = Foswiki::Func::getPreferencesValue("SECUREDOWNLOADS", $downloadWeb);
    ($downloadWeb, $downloadTopic) = Foswiki::Func::normalizeWebTopicName($downloadWeb, $downloadTopic)
      if $downloadTopic;
  } 

  ($downloadWeb, $downloadTopic) = Foswiki::Func::normalizeWebTopicName(undef, $this->{downloadArea})
    unless $downloadTopic;

  _writeDebug("downloadWeb=$downloadWeb, downloadTopic=$downloadTopic");
  my $topicObject = Foswiki::Meta->new($session, $downloadWeb, $downloadTopic);

  # (4) check download area exists
  unless ($topicObject->existsInStore()) {
    $response->status(404);
    $response->print("404 - download area does not exist\n");
    return;
  }

  # (5) check file existence
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

  my $fileLocation = $location.'/'.$downloadWeb.'/'.$downloadTopic.'/'.$fileName;
  my $filePath = $Foswiki::cfg{PubDir}.'/'.$downloadWeb.'/'.$downloadTopic.'/'.$fileName;

  my @stat = stat($filePath);
  my $lastModified = Foswiki::Time::formatTime($stat[9] || $stat[10] || 0, '$http', 'gmtime');
  my $ifModifiedSince = $request->header('If-Modified-Since') || '';

  _writeDebug("filePath=$filePath, fileLocation=$fileLocation");
  _writeDebug("lastModified=$lastModified, ifModifiedSince=$ifModifiedSince");

  my $dispositionMode = $Foswiki::cfg{SecureDownloadPlugin}{Disposition} || 'redirect';

  if ($lastModified eq $ifModifiedSince) {
    $response->header(
      -status => 304,
    );
  } else {
    $response->header(
      -status => 200,
      -type => $this->mimeTypeOfFile($filePath),
      -content_disposition => "$dispositionMode; filename=\"$fileName\"",
      $headerName => $fileLocation,
    );
  }

  return;
}

sub mmagic {
  my $this = shift;

  unless ($this->{_mmagic}) {

    eval { require File::MMagic::XS; };

    if ($@) {
      eval { require File::MMagic; };

      throw Error::Simple("couldn't load File::MMagic or File::MMagic::XS")
        if $@;
      
      $this->{_mmagic} = File::MMagic->new();
    } else {
      $this->{_mmagic} = File::MMagic::XS->new();
    }
  }

  return $this->{_mmagic};
}

sub checkMimeType {
  my ($this, $file) = @_;

  my $mmagic = $this->mmagic;

  return $mmagic->checktype_filename($file)
    if (ref(mmagic()) eq 'File::MMagic');

  return $mmagic->get_mime($file);
}

sub mimeTypeOfFile {
  my ($this, $fileName) = @_;

  my $mimeType;
  if ($fileName && $fileName =~ /\.([^.]+)$/) {
    my $suffix = $1;

    $this->{_mimeTypeInfo} //= Foswiki::Func::readFile($Foswiki::cfg{MimeTypesFileName});

    if ($this->{_mimeTypeInfo} =~ /^([^#]\S*).*?\s$suffix(?:\s|$)/im) {
      $mimeType = $1;
      _writeDebug("mimetypes file says $mimeType to $fileName");
      return $mimeType;
    }
  }

  $mimeType = $this->checkMimeType($fileName);

  if (defined $mimeType && $mimeType ne "x-system/x-error") {
    _writeDebug("mmagic says $mimeType to $fileName");
    return $mimeType;
  }

  _writeDebug("unknown mime type of $fileName");

  return 'application/octet-stream';
}

sub _writeDebug {
  return unless TRACE;
  print STDERR "SecureDownloadPlugin - $_[0]\n";
  #Foswiki::Func::_writeDebug("SecureDownloadPlugin::Core - $_[0]");
}

























1;
