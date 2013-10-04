#!/bin/bash
echo 'Setup-web2py-nginx-uwsgi-debian7.sh'
echo 'Requires Debian > 7 (Wheezy) and installs Nginx + uWSGI + Web2py'
# Check if user has root privileges
if [[ $EUID -ne 0 ]]; then
   echo "You must run the script as root or using sudo"
   exit 1
fi


# Get Web2py Application Name
echo -e "Web2py Application Name: \c "
read  APPNAME
echo

# Get Domain Name
echo -e "Enter app's domains names (Ex: www.example.com, example.com): \c "
read  DOMAINS
echo

# Get Web2py Admin Password
echo -e "Web2py Admin Password: \c "
read  PW

# Upgrade and install needed software
apt-get update
apt-get -y upgrade
apt-get -y autoremove
apt-get -y autoclean
echo "Installing nginx"
apt-get -y install nginx
apt-get -y install build-essential python-dev libxml2-dev python-pip unzip wipe
pip install --upgrade pip
PIPPATH=`which pip`

echo "Installing uWSGI"
$PIPPATH install --upgrade uwsgi
echo


# Create common nginx sections
echo "Configuring nginx's $APPNAME config at /etc/nginx/conf.d/$APPNAME"
mkdir /etc/nginx/conf.d/"$APPNAME"
echo '
gzip_static on;
gzip_http_version   1.1;
gzip_proxied        expired no-cache no-store private auth;
gzip_disable        "MSIE [1-6]\.";
gzip_vary           on;
' > /etc/nginx/conf.d/"$APPNAME"/gzip_static.conf
echo '
gzip on;
gzip_disable "msie6";
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_buffers 16 8k;
gzip_http_version 1.1;
gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
' > /etc/nginx/conf.d/"$APPNAME"/gzip.conf


# Create configuration file /etc/nginx/sites-available/"$APPNAME"
echo "server {
        listen          80;
        server_name     $DOMAINS;

        ###to enable correct use of response.static_version
        #location ~* ^/(\w+)/static(?:/_[\d]+\.[\d]+\.[\d]+)?/(.*)$ {
        #    alias /home/www-data/$APPNAME/applications/\$1/static/\$2;
        #    expires max;
        #}
        ###

        ###if you use something like myapp = dict(languages=['en', 'it', 'jp'], default_language='en') in your routes.py
        #location ~* ^/(\w+)/(en|it|jp)/static/(.*)$ {
        #    alias /home/www-data/$APPNAME/applications/\$1/;
        #    try_files static/\$2/\$3 static/\$3 = 404;
        #}
        ###

        location ~* ^/(\w+)/static/ {
            root /home/www-data/$APPNAME/applications/;
            #remove next comment on production
            #expires max;
            ### if you want to use pre-gzipped static files (recommended)
            ### check scripts/zip_static_files.py and remove the comments
            # include /etc/nginx/conf.d/$APPNAME/gzip_static.conf;
            ###
        }

        location / {
            #uwsgi_pass      127.0.0.1:9001;
            uwsgi_pass      unix:///tmp/$APPNAME.socket;
            include         uwsgi_params;
            uwsgi_param     UWSGI_SCHEME \$scheme;
            uwsgi_param     SERVER_SOFTWARE    'nginx/\$nginx_version';

            ###remove the comments to turn on if you want gzip compression of your pages
            # include /etc/nginx/conf.d/$APPNAME/gzip.conf;
            ### end gzip section

            ### remove the comments if you use uploads (max 10 MB)
            #client_max_body_size 10m;
            ###
        }
}

server {
        listen 443 ssl;
        server_name     $DOMAINS;

        ssl_certificate         /etc/nginx/ssl/$APPNAME.crt;
        ssl_certificate_key     /etc/nginx/ssl/$APPNAME.key;
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;
        ssl_ciphers ECDHE-RSA-AES256-SHA:DHE-RSA-AES256-SHA:DHE-DSS-AES256-SHA:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA;
        ssl_protocols SSLv3 TLSv1;
        keepalive_timeout    70;

        location / {
            #uwsgi_pass      127.0.0.1:9001;
            uwsgi_pass      unix:///tmp/$APPNAME.socket;
            include         uwsgi_params;
            uwsgi_param     UWSGI_SCHEME \$scheme;
            uwsgi_param     SERVER_SOFTWARE    'nginx/\$nginx_version';
            ###remove the comments to turn on if you want gzip compression of your pages
            # include /etc/nginx/conf.d/$APPNAME/gzip.conf;
            ### end gzip section
            ### remove the comments if you want to enable uploads (max 10 MB)
            #client_max_body_size 10m;
            ###
        }
        ## if you serve static files through https, copy here the section
        ## from the previous server instance to manage static files

}" >/etc/nginx/sites-available/"$APPNAME"

ln -s /etc/nginx/sites-available/"$APPNAME" /etc/nginx/sites-enabled/"$APPNAME"
rm /etc/nginx/sites-enabled/default
mkdir /etc/nginx/ssl
cd /etc/nginx/ssl

openssl genrsa 1024 > "$APPNAME".key
chmod 400 "$APPNAME".key
openssl req -new -x509 -nodes -sha1 -days 1780 -key "$APPNAME".key > "$APPNAME".crt
openssl x509 -noout -fingerprint -text < "$APPNAME".crt > "$APPNAME".info


# Prepare folders for uwsgi #################RETIRAR************************************
echo 'Preparing folders for uwsgi'
mkdir -p /etc/uwsgi
mkdir -p /var/log/uwsgi
#****************************************************************************************8

# Create configuration file /etc/uwsgi/"$APPNAME".ini
echo "Creating uwsgi configuration file /etc/uwsgi/$APPNAME.ini"
echo "[uwsgi]                                                                                                                                                                                         
                                                                                                                                                                                                
socket = /tmp/$APPNAME.socket                                                                                                                                                                     
pythonpath = /home/www-data/$APPNAME/                                                                                                                                                             
mount = /=wsgihandler:application                                                                                                                                                               
processes = 4                                                                                                                                                                                   
master = true                                                                                                                                                                                   
harakiri = 60
reload-mercy = 8
cpu-affinity = 1
stats = /tmp/$APPNAME.stats.socket
max-requests = 2000
limit-as = 512
reload-on-as = 256
reload-on-rss = 192
uid = www-data
gid = www-data
cron = 0 0 -1 -1 -1 python /home/www-data/$APPNAME/web2py.py -Q -S welcome -M -R scripts/sessions2trash.py -A -o
no-orphans = true
enable-threads = true
" >/etc/uwsgi/"$APPNAME".ini




#Create a default settings file for uwsgi daemon
echo 'Create a default settings file for uwsgi daemon'

echo ' # Default settings for uwsgi. This file is sourced by /usr/local/bin/uwsgi from /etc/init.d/uwsgi.
#Gracefuly provided by setup-web2py-nginx-uwsgi-debian7.sh 

# Options to pass to /etc/init.d/uwsgi
CONFIG_DIR="/etc/uwsgi/"
LOG_FILE="/var/log/uwsgi/uwsgi.log" 

' > /etc/default/uwsgi



#Create a configuration file for uwsgi in emperor-mode
#for System V in /etc/init.d/uwsgi
echo '#! /bin/sh
### BEGIN INIT INFO
# Provides:          uwsgi
# Required-Start:    $syslog
# Required-Stop:     $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts uwsgi in emperor mode
# Description:       starts uwsgi in emperor mode according /etc/uwsgi/*
#                    
### END INIT INFO

# Author: Upgrade Solutions <upgrade@upgradesolutions.com.br>

# Do NOT "set -e"

# PATH should only include /usr/* if it runs after the mountnfs.sh script
PATH=/usr/local/bin:/usr/local/sbin:/sbin:/usr/sbin:/bin:/usr/bin
DESC="uWSGI in Emperor Mode"
NAME=uwsgi
DAEMON=/usr/local/bin/$NAME
DAEMON_ARGS=
PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME

# Exit if the package is not installed
[ -x "$DAEMON" ] || exit 0

# Read configuration variable file if it is present
[ -r /etc/default/$NAME ] && . /etc/default/$NAME

DAEMON_ARGS="--master --die-on-term --emperor "$CONFIG_DIR" --daemonize "$LOG_FILE" "

# Load the VERBOSE setting and other rcS variables
. /lib/init/vars.sh

# Define LSB log_* functions.
# Depend on lsb-base (>= 3.2-14) to ensure that this file is present
# and status_of_proc is working.
. /lib/lsb/init-functions

#
# Function that starts the daemon/service
#
do_start()
{
    # Return
    #   0 if daemon has been started
    #   1 if daemon was already running
    #   2 if daemon could not be started
    start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON --test > /dev/null \
        || return 1
    start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON -- \
        $DAEMON_ARGS \
        || return 2
    # Add code here, if necessary, that waits for the process to be ready
    # to handle requests from services started subsequently which depend
    # on this one.  As a last resort, sleep for some time.
}

#
# Function that stops the daemon/service
#
do_stop()
{
    # Return
    #   0 if daemon has been stopped
    #   1 if daemon was already stopped
    #   2 if daemon could not be stopped
    #   other if a failure occurred
    start-stop-daemon --stop --quiet --retry=TERM/30/KILL/5 --pidfile $PIDFILE --name $NAME
    RETVAL="$?"
    [ "$RETVAL" = 2 ] && return 2
    # Wait for children to finish too if this is a daemon that forks
    # and if the daemon is only ever run from this initscript.
    # If the above conditions are not satisfied then add some other code
    # that waits for the process to drop all resources that could be
    # needed by services started subsequently.  A last resort is to
    # sleep for some time.
    start-stop-daemon --stop --quiet --oknodo --retry=0/30/KILL/5 --exec $DAEMON
    [ "$?" = 2 ] && return 2
    # Many daemons dont delete their pidfiles when they exit.
    rm -f $PIDFILE
    return "$RETVAL"
}

#
# Function that sends a SIGHUP to the daemon/service
#
do_reload() {
    #
    # If the daemon can reload its configuration without
    # restarting (for example, when it is sent a SIGHUP),
    # then implement that here.
    #
    start-stop-daemon --stop --signal 1 --quiet --pidfile $PIDFILE --name $NAME
    return 0
}

case "$1" in
  start)
    [ "$VERBOSE" != no ] && log_daemon_msg "Starting $DESC" "$NAME"
    do_start
    case "$?" in
        0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
        2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
    esac
    ;;
  stop)
    [ "$VERBOSE" != no ] && log_daemon_msg "Stopping $DESC" "$NAME"
    do_stop
    case "$?" in
        0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
        2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
    esac
    ;;
  status)
    status_of_proc "$DAEMON" "$NAME" && exit 0 || exit $?
    ;;
  reload|force-reload)
    #
    # If do_reload() is not implemented then leave this commented out
    # and leave "force-reload" as an alias for "restart".
    #
    log_daemon_msg "Reloading $DESC" "$NAME"
    do_reload
    log_end_msg $?
    ;;
  restart) #|force-reload)
    #
    # If the "reload" option is implemented then remove the
    # "force-reload" alias
    #
    log_daemon_msg "Restarting $DESC" "$NAME"
    do_stop
    case "$?" in
      0|1)
        do_start
        case "$?" in
            0) log_end_msg 0 ;;
            1) log_end_msg 1 ;; # Old process is still running
            *) log_end_msg 1 ;; # Failed to start
        esac
        ;;
      *)
        # Failed to stop
        log_end_msg 1
        ;;
    esac
    ;;
  *)
    #echo "Usage: $SCRIPTNAME {start|stop|restart|reload|force-reload}" >&2
    echo "Usage: $SCRIPTNAME {start|stop|status|restart|force-reload}" >&2
    exit 3
    ;;
esac

:' > /etc/init.d/uwsgi

# Set default settings to initialize uwsgi at boot
echo "Configuring System-V's uwsgi script"
chmod 755 /etc/init.d/uwsgi
update-rc.d defaults uwsgi


# Install Web2py
mkdir /home/www-data
cd /home/www-data
wget http://web2py.com/examples/static/web2py_src.zip
unzip web2py_src.zip
rm web2py_src.zip
mv web2py "$APPNAME"
# Download latest version of sessions2trash.py
wget http://web2py.googlecode.com/hg/scripts/sessions2trash.py -O /home/www-data/"$APPNAME"/scripts/sessions2trash.py
chown -R www-data:www-data "$APPNAME"
cd /home/www-data/"$APPNAME"
sudo -u www-data python -c "from gluon.main import save_password; save_password('$PW',443)"


#Create app remove(wipe) script
echo "Creating app remove(wipe) script at /home/www-data/$APPNAME/$APPNAME_wipe_app.sh"
echo "
#!/bin/bash
wipe -qrfQ 1 /etc/uwsgi/$APPNAME.ini /tmp/$APPNAME* /home/www-data/$APPNAME
/etc/init.d/nginx stop
find /etc/nginx/ -name *$APPNAME* -exec wipe -qrfQ 1 {} \\;
/etc/init.d/uwsgi reload
/etc/init.d/nginx start
" > /home/www-data/"$APPNAME"/"$APPNAME"_wipe_app.sh && chmod +x /home/www-data/"$APPNAME"/"$APPNAME"_wipe_app.sh

#(Re)Start services
echo '(Re)Starting services'
/etc/init.d/uwsgi restart 
/etc/init.d/nginx restart
echo 'Done! Enjoy your app!'
echo



## you can reload uwsgi with
# /etc/init.d/uwsgi reload
## and stop it with
# /etc/init.d/uwsgi stop
## to reload web2py only (without restarting uwsgi)
# touch /etc/uwsgi/"$APPNAME".ini
