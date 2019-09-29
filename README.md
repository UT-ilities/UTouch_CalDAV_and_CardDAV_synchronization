# Overview

This utility is a fancy wrapper around `syncevolution` and `cron` and it creates or removes connections to remote carddav/caldav servers. This utility was created specifically to work on Ubuntu Touch but it may work in different environments.

# How To Use

Configure server URLs, credentials, and naming preferences.

    cp config-nextcloud-template.txt config-personal.txt
    vim config-personal.txt

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
