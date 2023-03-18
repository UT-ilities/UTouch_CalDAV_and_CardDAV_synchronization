# Overview

This utility is a fancy wrapper around `syncevolution` and `cron` and it creates or removes connections to remote carddav/caldav servers. This utility was created specifically to work on Ubuntu Touch but it may work in different environments.

# Get the Code.

    git clone https://github.com/UT-ilities/UTouch_CalDAV_and_CardDAV_synchronization.git
    cd UTouch_CalDAV_and_CardDAV_synchronization

# How To Use

Configure server URLs, credentials, and naming preferences.
We assume that you can use non-sytandard NextCloud setup (different network port and 2FA enabled) so you need to provide:
- a real NC user (```USERNAME```)
- a Device credentials (```NCLOGIN```) (see https://docs.nextcloud.com/server/latest/user_manual/id/session_management.html)
- a network port that NC is accepting connections on (```NCPORT```) that defaults to 443

In case of a standard setup (default port and no 2FA enabled) ```USERNAME``` and ```NCLOGIN``` should be the same and ```PASSWORD``` is your NC user pass.

    cp config-nextcloud-template.txt config-personal.txt
    vim config-personal.txt
In order to login using your Device(App) password (thus not exposing your real NC user and pass and bypass oAuth) in current NC version (starting from NC 19) if a Device password is generated you are presented with a pair of login/password. Enter generated login in ```NCLOGIN``` and password in ```PASSWORD``` into your ```config-personal.txt```.

Executing `setup-dav-sync.sh --contacts config-personal.txt` or `setup-dav-sync.sh --calendar config-personal.txt` will read your configurations, connect to the specified carddav/caldav server, synchronize data and setup a cron job to keep this device in sync with the server.

Executing `setup-dav-sync.sh --delete-contacts config-personal.txt` or `setup-dav-sync.sh --delete-calendar config-personal.txt` will read your configurations, remove them from `syncevolution` configurations and remove all data from this device only (the data on the server will not be affected).

# Using Multiple Carddav/Caldav Servers.

Simple specify multiple configurations files and a single command will process them all.

    setup-dav-sync.sh --contacts --calendar config-personal.txt holidays.txt team-awesome-schedule.txt

# Known Bugs

1. When a contact is delete from Ubuntu Touch using the native Contacts app `syncevolution` will relay this change to the carddav server as a 'modification' of the contact and it will not be deleted from the server and other clients synchronized with the server will still have this _old_ contact.
2. Even after a calendar has been removed it will still show up as an available calendar in the Ubuntu Touch native calendar app.

# Recommendations for Nextcloud Users.

I do NOT recommend using this utility to synchronize calendars hosted in Nextcloud. The online accounts feature of Ubuntu Touch does a better job.
I do recommend using this to synchronize contacts.

# Pull Requests Are Welcomed
I am only able to test configurations and servers I use, which currently is Nextcloud. I will be happy to incorporate changes which allow a larger audience to benefit from this project.
