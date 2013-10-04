#!/bin/bash
echo 'Starting script setup-new-web2py_app-debian7.sh'
echo 'Requires Debian > 7 (Wheezy) and installs a new Web2py application'
echo

# Check if user has root privileges
if [[ $EUID -ne 0 ]]; then
   echo "You must run the script as root or using sudo"
   exit 1
fi

echo "Supposing you've already install uwsgi and nginx"
echo "(if you don't please run setup-web2py-nginx-uwsgi-debian7.sh script instead)"
echo -e "Did you ?(Y/n): \c"
read ANSWER

ANSWER=${ANSWER:="y"}
if [ "$ANSWER" != "Y" ] && [ "$ANSWER" != "y" ]
then
    echo "Please run setup-web2py-nginx-uwsgi-debian7.sh script"
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


# Create common nginx sections
mkdir -p /etc/nginx/conf.d/"$APPNAME"
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

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
echo 'Done! Enjoy your new app!'
echo



## you can reload uwsgi with
# /etc/init.d/uwsgi reload
## and stop it with
# /etc/init.d/uwsgi stop
## to reload web2py only (without restarting uwsgi)
# touch /etc/uwsgi/"$APPNAME".ini
