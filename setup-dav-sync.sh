#!/usr/bin/env bash

CONFIGS='configs.txt'
source configs.txt

function setup_sync {
    SYNC="export DISPLAY=:0.0 && export DBUS_SESSION_BUS_ADDRESS=\$(ps -u $USER e | grep -Eo 'dbus-daemon.*address=unix:abstract=/tmp/dbus-[A-Za-z0-9]{10}' | tail -c35) && /usr/bin/syncevolution $1"
    CRON_SYNC="$CRON_FREQUENCY $SYNC"
    REGEX_SEARCH="^.*$1.*$"
    CRON_TAB="/var/spool/cron/crontabs/$USER"
    GREP_RESULT=$(grep --only-matching "$REGEX_SEARCH" $CRON_TAB)
    sudo mount / -o remount,rw
    # if a matching entry exists replace it
    if [ ! -z "$GREP_RESULT" ]; then
        sudo sed --in-place --expression="s|$REGEX_SEARCH|$CRON_SYNC|" $CRON_TAB
    else
        sudo echo "$SYNC" >> $CRON_TAB
    fi
    sudo service cron restart
    if [ ! -d $HOME/bin ]; then
        mkdir $HOME/bin
    fi
    SCRIPT_NAME="$HOME/bin/manual-sync-$2.sh"
    echo "$SYNC" > $SCRIPT_NAME
    chmod +x $SCRIPT_NAME
    echo "manual sync script created at $SCRIPT_NAME"
    sudo mount / -o remount,ro
}

function delete {
    SERVER_CONFIG_NAME="$1"
    NAME="$2"
    VISUAL_NAME="$3"

    syncevolution --remove-database backend=evolution-contacts database="$VISUAL_NAME" &>/dev/null
    syncevolution --remove "target-config@$SERVER_CONFIG_NAME"
    syncevolution --remove "@$SERVER_CONFIG_NAME"
    syncevolution --remove "$SERVER_CONFIG_NAME"
    # I cannot find the `syncevolution` command to remove this configuration
    rm --recursive --force $HOME/.config/syncevolution/default/sources/$2
}

function delete-contacts {
    delete "$CONTACTS_SERVER_CONFIG_NAME" "$CONTACTS_VISUAL_NAME" "$CONTACTS_NAME"
}

function delete-calendar {
    delete "$CALENDAR_SERVER_CONFIG_NAME" "$CALENDAR_VISUAL_NAME" "$CALENDAR_NAME"
}

function contacts {
    # add cron entry and create manual sync script
    setup_sync "$CONTACTS_SERVER_CONFIG_NAME" "$CONTACTS_NAME"

    #Create contact list
    syncevolution --create-database backend=evolution-contacts database="$CONTACTS_VISUAL_NAME"
    
    #Create Peer
    syncevolution --configure --template webdav username="$USERNAME" password="$PASSWORD" syncURL="$CONTACTS_URL" keyring=no "target-config@$CONTACTS_SERVER_CONFIG_NAME"
    
    #Create New Source
    syncevolution --configure backend=evolution-contacts database="$CONTACTS_VISUAL_NAME" @default "$CONTACTS_NAME"
    
    #Add remote database
    syncevolution --configure database="$CONTACTS_URL" backend=carddav "target-config@$CONTACTS_SERVER_CONFIG_NAME" "$CONTACTS_NAME"
    
    #Connect remote contact list with local databases
    syncevolution --configure --template SyncEvolution_Client Sync=None syncURL="local://@$CONTACTS_SERVER_CONFIG_NAME" "$CONTACTS_SERVER_CONFIG_NAME" "$CONTACTS_NAME"
    
    #Add local database to the source
    syncevolution --configure sync=two-way backend=evolution-contacts database="$CONTACTS_VISUAL_NAME" "$CONTACTS_SERVER_CONFIG_NAME" "$CONTACTS_NAME"
    
    #Start first sync
    syncevolution --sync refresh-from-remote "$CONTACTS_SERVER_CONFIG_NAME" "$CONTACTS_NAME"
}
    
function calendar {
    # add cron entry and create manual sync script
    setup_sync "$CALENDAR_SERVER_CONFIG_NAME" "$CALENDAR_NAME"

    #Create Calendar
    syncevolution --create-database backend=evolution-calendar database="$CALENDAR_VISUAL_NAME"
    
    #Create Peer
    syncevolution --configure --template webdav username="$USERNAME" password="$PASSWORD" syncURL="$CAL_URL" keyring=no "target-config@$CALENDAR_SERVER_CONFIG_NAME"
    
    #Create New Source
    syncevolution --configure backend=evolution-calendar database="$CALENDAR_VISUAL_NAME" @default "$CALENDAR_NAME"
    
    #Add remote database
    syncevolution --configure database="$CAL_URL" backend=caldav "target-config@$CALENDAR_SERVER_CONFIG_NAME" "$CALENDAR_NAME"
    
    #Connect remote calendars with local databases
    syncevolution --configure --template SyncEvolution_Client syncURL="local://@$CALENDAR_SERVER_CONFIG_NAME" "$CALENDAR_SERVER_CONFIG_NAME" "$CALENDAR_NAME"
    
    #Add local database to the source
    syncevolution --configure sync=two-way database="$CALENDAR_VISUAL_NAME" "$CALENDAR_SERVER_CONFIG_NAME" "$CALENDAR_NAME"
    
    #Start first sync
    syncevolution --sync refresh-from-remote "$CALENDAR_SERVER_CONFIG_NAME" "$CALENDAR_NAME"
}

function help {
    echo 'Usage:'
    echo "   $0 --contacts --calendar"
    echo "   $0 --contacts"
    echo "   $0 --calendar"
    echo "   $0 --delete-contacts --delete-calendar"
    echo "   $0 --delete-contacts"
    echo "   $0 --delete-calendar"
    echo "   $0 -h | --help"
    exit 1
}

if [ $# -eq 0 ]; then
    echo 'No arguments given'
    help
fi

TEMP=$(getopt --options 'h' --long 'calendar,contacts,delete-calendar,delete-contacts,help' --name "$0" -- "$@")

if [ $? -ne 0 ]; then
    echo 'Terminating...' >&2
    exit 1
fi

eval set -- "$TEMP"
unset TEMP



while true; do
    case "$1" in
        '-h'|'--help')
            help
        ;;
        '--contacts')
            contacts
            shift
            continue
        ;;
        '--calendar')
            calendar
            shift
            continue
        ;;
        '--delete-contacts')
            delete-contacts
            shift
            continue
        ;;
        '--delete-calendar')
            delete-calendar
            shift
            continue
        ;;
        '--')
            # end of parameters
            shift
            break
        ;;
        *)
            echo 'Internal error!' >&2
            exit 1
        ;;
    esac
done
