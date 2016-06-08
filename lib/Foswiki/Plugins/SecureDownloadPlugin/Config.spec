# ---+ Extensions
# ---++ SecureDownloadPlugin
# This is the configuration used by the <b>SecureDownloadPlugin</b>.

# **PERL EXPERT**
# This setting is required to enable executing the xsendfile service from the bin directory
$Foswiki::cfg{SwitchBoard}{download} = {
  package  => 'Foswiki::Plugins::SecureDownloadPlugin',
  function => 'download',
  context  => { download => 1 },
};

# **STRING**
# Specifies the area to hold all secured files. WARNING: make sure the location is protected against
# normal access by Foswiki ACLs
$Foswiki::cfg{SecureDownloadPlugin}{DownloadArea} = 'System.SecureDownloads';

# **STRING**
# Specifies the topic to redirect to in case the resource is gone. This can be a 'web.topic' or
# an URL. Leave empty to return a http error code.
$Foswiki::cfg{SecureDownloadPlugin}{Redirect} = '';

# **SELECT none,X-Sendfile,X-LIGHTTPD-send-file,X-Accel-Redirect**
# Enable efficient delivery of files 
# using the xsendfile feature available in apache, nginx and lighttpd.
# Use <ul>
# <li>X-Sendfile for Apache2 <li>
# <li>X-LIGHTTPD-send-file for Lighttpd<li>
# <li>X-Accel-Redirect for Nginx<li>
# </ul>
# Note that you will need to configure your http server accordingly.
# Leave empty to default to values configured in XSendFileContrib if installed as well.
$Foswiki::cfg{SecureDownloadPlugin}{XSendFileHeader} = '';

# **SELECT redirect,inline**
# Specifies the way the download is delivered. <ul>
# <li>redirect (default): opens a download dialog in the browser</li>
# <li>inline: opens the download inside the browser as far as possible (e.g. pdf, images, ...)</li>
# </ul>
$Foswiki::cfg{SecureDownloadPlugin}{Disposition} = 'redirect';

# **PATH**
# Location that the http server will process internally to send protected files.
# Leave it to {PubDir} for Lighttpd; use the <code>/protected_files</code> location
# as configured for an Nginx.
$Foswiki::cfg{XSendFileContrib}{Location} = '';

# **STRING**
# Time in seconds that a secured url is valid.
$Foswiki::cfg{SecureDownloadPlugin}{Timeout} = 60;

# **PASSWORD H**
# Hidden secret added to tokens. WARNING: please change default values
$Foswiki::cfg{SecureDownload}{Secret} = '';

1;
