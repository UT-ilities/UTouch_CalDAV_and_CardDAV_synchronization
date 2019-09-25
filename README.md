# Overview

This utility is a fancy wrapper around `syncevolution` and `cron` and it creates or removes connections to remote carddav/caldav servers. This utility was created specifically to work on Ubuntu Touch but it may work in different environments.

# How To Use

Configure server URLs, credentials, and naming preferences.

    vim config.txt

Executing `setup-dav-sync.sh --contacts` or `setup-dav-sync.sh --calendar` or `setup-dav-sync.sh --contacts --calendar` will read your configurations, connect to the specified carddav/caldav server, synchronize data and setup a cron job to keep this device in sync with the server.

Executing `setup-dav-sync.sh --delete-contacts` or `setup-dav-sync.sh --delete-calendar` or `setup-dav-sync.sh --delete-contacts --delete-calendar` will read your configurations, remove them from `syncevolution` configurations and remove all data from this device only (the data on the server will not be affected).

# Using Multiple Carddav/Caldav Servers.

It is possible to use this utility with multiple servers; the easiest approach is to create a config file for each server (i.e. `config-nextcloud.txt`, `config-google.txt`) and symbolically link one config file at a time to `config.txt`.

    ln --symbolic --force --no-target-directory configs-nextcloud.txt configs.txt

# Known Bugs

When a contact is delete from Ubuntu Touch using the native Contacts app `syncevolution` will relay this change to the carddav server as a 'modification' of the contact and it will not be deleted from the server and other clients synchronized with the server will still have this _old_ contact.

# Pull Requests Are Welcomed
I am only able to test configurations and servers I use, which currently is Nextcloud. I will be happy to incorporate changes which allow a larger audience to benefit from this project.
