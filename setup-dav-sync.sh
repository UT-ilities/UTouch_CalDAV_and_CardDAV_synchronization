#!/usr/bin/env bash

function generate_padding {
    # get the first character ':0:1' - aka index zero to one
    local symbol="${1:0:1}"
    shift # drop input parameter '1' and shift all parameters to the left

    local -i offset=$1
    shift

    declare -g padding=''

    # iterate over the remaining input parameters
    local param
    for param in "$@"; do
        # iterate over string length
        local i
        for (( i = 0; i < ${#param}; i++ )); do
            padding="$padding$symbol"
        done
    done

    # include padding for the gaps between words
    local i
    for (( i = 0; i < $# - 1; i++ )); do
        padding="$padding$symbol"
    done

    local i
    for (( i = 0; i < $offset; i++ )); do
        padding="$padding$symbol"
    done
}

function cron_handler {
    local action="$1" # either 'add' or 'delete'
    local server_config_name="$2"
    local cron_entry="$3"

    local cron_tab="/var/spool/cron/crontabs/$USER"
    local regex_search="^.*$server_config_name.*$"

    sudo mount / -o remount,rw

    case "$action" in
        'add')
            if sudo [ -f "$cron_tab" ]; then
                local grep_result=$(sudo grep --only-matching "$regex_search" "$cron_tab")

                # if a matching cron entry exists replace it
                if [ ! -z "$grep_result" ]; then
                    echo "cron - updating entry for '$server_config_name'"
                    sudo sed --in-place --expression="s|$regex_search|$cron_entry|" "$cron_tab"
                else
                    echo "cron - creating new entry for '$server_config_name'"
                    echo "$cron_entry" | sudo tee  --append "$cron_tab" &>/dev/null
                fi
            else
                echo "User's cron tab not found, creating it."
                sudo touch "$cron_tab"
                sudo chown $USER:clickpkg "$cron_tab" # non portable operation
                sudo chmod 600 "$cron_tab"

                echo "$cron_entry" | sudo tee  --append "$cron_tab" &>/dev/null
            fi
        ;;
        'delete')
            if sudo [ -f "$cron_tab" ]; then
                local grep_result=$(sudo grep --only-matching "$regex_search" "$cron_tab")

                # if a matching cron entry exists delete it
                if [ ! -z "$grep_result" ]; then
                    echo "cron - deleting entry for '$server_config_name'"
                    sudo sed --in-place --expression="/$regex_search/d" "$cron_tab"
                else
                    echo "cron - no entry found for '$server_config_name'"
                fi
            else
                echo "User's cron tab not found, no action taken on cron tab."
            fi
        ;;
        *)
            sudo mount / -o remount,ro
            echo 'Internal error!' >&2
            echo "in the '${FUNCNAME[0]}' function" >&2
            exit 1
        ;;
    esac

    sudo service cron restart &>/dev/null

    sudo mount / -o remount,ro

}

function manual_sync {
    local action="$1" # either 'add' or 'delete'
    local name="$2"
    local sync="$3" # only needed for the 'add' action

    local script_name="$HOME/bin/manual-sync-$name.sh"

    case "$action" in
        'add')
            echo "$sync" > $script_name
            chown $USER:$USER $script_name
            chmod 775 $script_name

            local symbol='#'
            local header='manual sync script created at:'
            generate_padding "$symbol" 4 "$header" "$script_name"
            echo "$padding"
            echo "$symbol $header $script_name $symbol"
            echo "$padding"
        ;;
        'delete')
            if [ -f "$script_name" ]; then
                rm "$script_name"
            fi

            local symbol='#'
            local header="manual sync script '$script_name' has been deleted"
            generate_padding "$symbol" 4 "$header"
            echo "$padding"
            echo "$symbol $header $symbol"
            echo "$padding"
        ;;
        *)
            sudo mount / -o remount,ro
            echo 'Internal error!' >&2
            echo "in the '${FUNCNAME[0]}' function" >&2
            exit 1
        ;;
    esac
}

function setup_sync {
    local server_config_name="$1"
    local name="$2"

    local sync="export DISPLAY=:0.0 && export DBUS_SESSION_BUS_ADDRESS=\$(ps -u $USER e | grep -Eo 'dbus-daemon.*address=unix:abstract=/tmp/dbus-[A-Za-z0-9]{10}' | tail -c35) && /usr/bin/syncevolution $server_config_name"
    local cron_entry="$CRON_FREQUENCY $sync"
    local action='add'

    cron_handler "$action" "$server_config_name" "$cron_entry"

    if [ ! -d $HOME/bin ]; then
        mkdir $HOME/bin
    fi

    manual_sync "$action" "$name" "$sync"
}

function delete {
    local server_config_name="$1"
    local name="$2"
    local visual_name="$3"

    local action='delete'
    cron_handler "$action" "$server_config_name"
    manual_sync "$action" "$name"

    syncevolution --remove-database backend=evolution-contacts \
        database="${visual_name:0:30}" &>/dev/null
    syncevolution --remove "target-config@${server_config_name:0:30}"
    syncevolution --remove "@${server_config_name:0:30}"
    syncevolution --remove "${server_config_name:0:30}"
    # I cannot find the `syncevolution` command to remove this configuration
    rm --recursive --force \
        $HOME/.config/syncevolution/default/sources/${name:0:30}
}

function delete-contacts {
    local i
    for (( i = 0; i < ${#CONTACTS_NAMES[@]}; i++ )); do
        delete "${CONTACTS_SERVER_CONFIG_NAMES[$i]}" \
               "${CONTACTS_NAMES[$i]}" "${CONTACTS_VISUAL_NAMES[$i]}"
    done
}

function delete-calendar {
    local i
    for (( i = 0; i < ${#CALENDAR_NAMES[@]}; i++ )); do
        delete "${CALENDAR_SERVER_CONFIG_NAMES[$i]}" \
               "${CALENDAR_NAMES[$i]}" "${CALENDAR_VISUAL_NAMES[$i]}"
    done
}

function contacts {
    local i
    for (( i = 0; i < ${#CONTACTS_NAMES[@]}; i++ )); do
        # syncevolution cannot handle names larger than 31 characters
        local contacts_server_config_names="${CONTACTS_SERVER_CONFIG_NAMES[$i]:0:30}"
        local contacts_names="${CONTACTS_NAMES[$i]:0:30}"
        local contacts_visual_names="${CONTACTS_VISUAL_NAMES[$i]:0:30}"

        local url="${CARD_URL%%/}/${CARD_NAMES[$i]}"


        # add cron entry and create manual sync script
        setup_sync "${CONTACTS_SERVER_CONFIG_NAMES[$i]}" \
                   "${CONTACTS_NAMES[$i]}"

        #Create contact list
        syncevolution --create-database backend=evolution-contacts \
                                        database="$contacts_visual_names"

        #Create Peer
        #if (( ${#USERNAME} != 0 )) || (( ${#PASSWORD} != 0 )); then
        if (( ${#PASSWORD} != 0 )); then
            syncevolution --configure --template webdav username="$USERNAME" \
                password="$PASSWORD" syncURL="$url" \
                keyring=no "target-config@$contacts_server_config_names"
        else
            syncevolution --configure --template webdav syncURL="$url" \
                keyring=no "target-config@$contacts_server_config_names"
        fi

        #Create New Source
        syncevolution --configure backend=evolution-contacts \
            database="$contacts_visual_names" @default "$contacts_names"

        #Add remote database
        syncevolution --configure database="$url" \
            backend=carddav "target-config@$contacts_server_config_names" \
            "$contacts_names"

        #Connect remote contact list with local databases
        syncevolution --configure --template SyncEvolution_Client \
            Sync=None syncURL="local://@$contacts_server_config_names" \
            "$contacts_server_config_names" "$contacts_names"

        #Add local database to the source
        syncevolution --configure sync=two-way backend=evolution-contacts \
            database="$contacts_visual_names" "$contacts_server_config_names" \
            "$contacts_names"

        #Start first sync
        syncevolution --sync refresh-from-remote \
            "$contacts_server_config_names" "$contacts_names"
    done
}

function calendar {
    local i
    for i in ${!CALENDAR_NAMES[@]}; do
        # syncevolution cannot handle names larger than 31 characters
        local calendar_server_config_names="${CALENDAR_SERVER_CONFIG_NAMES[$i]:0:30}"
        local calendar_names="${CALENDAR_NAMES[$i]:0:30}"
        local calendar_visual_names="${CALENDAR_VISUAL_NAMES[$i]:0:30}"

        local url="${CAL_URL%%/}/${CAL_NAMES[$i]}"

        # add cron entry and create manual sync script
        setup_sync "${CALENDAR_SERVER_CONFIG_NAMES[$i]}" "${CALENDAR_NAMES[$i]}"

        #Create Calendar
        syncevolution --create-database backend=evolution-calendar \
                                        database="$calendar_visual_names"

        #Create Peer
        #if (( ${#USERNAME} != 0 )) || (( ${#PASSWORD} != 0 )); then
        if (( ${#PASSWORD} != 0 )); then
            syncevolution --configure --template webdav username="$USERNAME" \
                password="$PASSWORD" syncURL="$url" keyring=no \
                "target-config@$calendar_server_config_names"
        else
            syncevolution --configure --template webdav syncURL="$url" \
                keyring=no "target-config@$calendar_server_config_names"
        fi

        #Create New Source
        syncevolution --configure backend=evolution-calendar \
            database="$calendar_visual_names" @default "$calendar_names"

        #Add remote database
        syncevolution --configure database="$url" backend=caldav \
            "target-config@$calendar_server_config_names" "$calendar_names"

        #Connect remote calendars with local databases
        syncevolution --configure --template SyncEvolution_Client \
            syncURL="local://@$calendar_server_config_names" \
            "$calendar_server_config_names" "$calendar_names"

        #Add local database to the source
        syncevolution --configure sync=two-way \
            database="$calendar_visual_names" "$calendar_server_config_names" \
            "$calendar_names"

        #Start first sync
        syncevolution --sync refresh-from-remote \
            "$calendar_server_config_names" "$calendar_names"
    done
}

function help {
    echo 'Usage:'
    echo "   $0 --contacts --calendar config1.txt [config2.txt ...]"
    echo "   $0 --contacts config1.txt [config2.txt ...]"
    echo "   $0 --calendar config1.txt [config2.txt ...]"
    echo "   $0 --delete-contacts --delete-calendar config1.txt [config2.txt ...]"
    echo "   $0 --delete-contacts config1.txt [config2.txt ...]"
    echo "   $0 --delete-calendar config1.txt [config2.txt ...]"
    echo "   $0 -h | --help"
    exit 1
}

if [ $# -eq 0 ]; then
    echo 'No arguments given'
    help
fi

TEMP=$(getopt --options 'h' --long 'calendar,contacts,delete-calendar,\
       delete-contacts,help' --name "$0" -- "$@")

if [ $? -ne 0 ]; then
    echo 'Terminating...' >&2
    exit 1
fi

eval set -- "$TEMP"
unset TEMP

contacts=false
calendar=false
delete_calendar=false
delete_contacts=false

while true; do
    case "$1" in
        '-h'|'--help')
            help
        ;;
        '--contacts')
            contacts=true
            shift
            continue
        ;;
        '--calendar')
            calendar=true
            shift
            continue
        ;;
        '--delete-contacts')
            delete_contacts=true
            shift
            continue
        ;;
        '--delete-calendar')
            delete_calendar=true
            shift
            continue
        ;;
        '--')
            # end of flags
            shift
            break
        ;;
        *)
            echo 'Internal error!' >&2
            echo 'in the flag decoding logic' >&2
            exit 1
        ;;
    esac
done

if $contacts && $delete_contacts; then
    echo 'contradictory flags set: --contacts and --delete_contacts'
    exit 1
fi

if $calendar && $delete_calendar; then
    echo 'contradictory flags set: --calendar and --delete_calendar'
    exit 1
fi

for config_file in "$@"; do
    if [ -f "$config_file" ]; then
        symbol='#'
        header="using configuration file:"
        generate_padding "$symbol" 4 "$header" "$config_file"
        echo "$padding"
        echo "$symbol $header $config_file $symbol"
        echo "$padding"

        source "$config_file"
    else
        echo "unable to read configuration file: $config_file, skipping"
        continue
    fi

    if $calendar; then
        calendar
    fi

    if $contacts; then
        contacts
    fi

    if $delete_calendar; then
        delete-calendar
    fi

    if $delete_contacts; then
        delete-contacts
    fi
done
