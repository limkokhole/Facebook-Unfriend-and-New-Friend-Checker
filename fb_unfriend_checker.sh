#!/bin/bash

# Check if fb_user_id is provided as a command-line argument
if [ -z "$1" ]; then
    echo 'Run this script from a Linux system connected to a rooted Android emulator or phone with USB debugging enabled and plugged in.'
    echo 'If you have just installed and logged into the Facebook app, you need to wait roughly half an hour to obtain the full database before running this script. In the worst-case scenario, you may need to kill the app and then relaunch it after a long time.'
    echo 'After unfriending, it also takes a while for the changes to be reflected in the database.'
    echo -e "\nUsage: $0 <fb_user_id> [check_type]\n"
    echo "check_type options: unfriend (default), new_friend, both"
    echo "Example: bash fb_unfriend_checker.sh 1202604355"
    echo "Example (specifying check_type): bash fb_unfriend_checker.sh 1202604355 both"
    echo -e 'ID can be obtained from the profile URL OR "View As", e.g., ...&id=1202604355'
    exit 1
fi

# Assign the first argument to fb_user_id
fb_user_id=$1

# Check if check_type is provided and valid
check_type=${2:-unfriend}  # Default to 'unfriend' if not provided

#<<"TEMPORARY_DISABLE_ADB" 
case "$check_type" in
    unfriend)
        action="removed"
        ;;
    new_friend)
        action="new"
        ;;
    both)
        action="both"
        ;;
    *)
        echo "Invalid check_type: $check_type"
        echo "Usage: $0 <fb_user_id> [check_type]"
        echo "check_type options: unfriend (default), new_friend, both"
        exit 1
        ;;
esac

echo 'Waiting for your emulator or phone via adb.'
adb wait-for-device

# Loop until an authorized device is connected
while true; do
  device_list=$(adb devices)
  if echo "$device_list" | grep -q "device$"; then
    echo "Device is connected and authorized."
    break  # Break out of the loop when a device is found
  else
    echo "No connected and authorized devices found."
    echo "Waiting 5 seconds before retrying..."
    sleep 5
  fi
done

# Loop until the device has finished booting
while true; do
  boot_completed=$(adb shell 'getprop sys.boot_completed' | tr -d '\r')  # Trim carriage return if necessary
  # Check if the boot_completed variable is non-empty and is a number
  if [[ "$boot_completed" =~ ^[0-9]+$ ]]; then
    if [ "$boot_completed" -eq 1 ]; then
      echo "Device has finished booting."
      break  # Exit the loop when device is fully booted
    else
      echo "Device has not finished booting. Please wait."
    fi
  else
    echo "Unable to determine boot status. Please ensure the device is connected properly."
  fi

  sleep 3  # Wait before retrying
done

adb root # Show "adbd cannot run as root in production builds" if normal non-rooted phone, but can continue go to next check file path loop

# Define the path to check on the Android device
file_path="/data/user/0/com.facebook.katana/app_mib_msys/v2/$fb_user_id/msys_database_$fb_user_id"

# Loop until the file exists
while true; do
  # Use adb to check if the file exists on the device
  if adb shell [ -f "$file_path" ]; then
    echo "File found: $file_path"
    break  # Exit the loop if the file is found
  else
    echo "Database file does not exist: $file_path"
    echo -e "\nEnsure that your phone or emulator is already rooted."
    echo "Ensure that your account has at least one friend."
    echo "If you have just installed and logged into the Facebook app, you need to wait roughly half an hour to obtain the full database before running this script."
    echo "Waiting for half an hour before retrying..."
    sleep 1800
  fi
done
#TEMPORARY_DISABLE_ADB

# Define the prefix
prefix="DB_fb_unfriend_"

# Paths to the database snapshots
snapshot_dir="$(pwd)" # If db inside current path
#snapshot_dir=~/Downloads/com.facebook.katana/app_mib_msys/v2/"$fb_user_id" # If hardcode db directory path

# Find the latest directory with full path
before_db=$(find "$snapshot_dir" -maxdepth 1 -type f -name "${prefix}*" -printf '%T+ %p\n' | sort -r | head -n 1 | cut -d ' ' -f 2-)

# Get the current date and time in a pretty format
# Example format: 2023-08-07_17-24-30
date_time=$(date "+%Y-%m-%d_%H-%M-%S")

after_db="${snapshot_dir}/"${prefix}"msys_database_${fb_user_id}_${date_time}"

# Pull the current state of the database from the device
adb pull "/data/user/0/com.facebook.katana/app_mib_msys/v2/$fb_user_id/msys_database_$fb_user_id" "$after_db"

# Check if the latest directory exists
if [ -f "$before_db" ]; then
    : # echo "The latest directory exists: $latest_dir"
else
    echo -e "\nNo previous directory found. It's normal if first time run. Re-run to diff."
    exit 1
fi

# Check if the pull output directory exists
if [ -f "$after_db" ]; then
    : # echo "The pull output directory exists: $latest_dir"
else
    echo -e "\nadb pull failed."
    exit 1
fi

echo "Lastest db: $before_db"
echo "Current db: $after_db"

# Perform the comparison based on the check_type
unfriend_output=""
if [ "$action" = "removed" ] || [ "$action" = "both" ]; then
    echo -e "\nFinding removed friends..."
    unfriend_output=$(sqlite3 <<EOF
    ATTACH DATABASE '$before_db' AS previous;
    ATTACH DATABASE '$after_db' AS current;

    /* This query identifies changes in contact_viewer_relationship when the previous value was 2. */
    SELECT current.id 
    FROM current.contacts AS current
    JOIN previous.contacts AS previous
    ON current.id = previous.id
    WHERE previous.contact_viewer_relationship = 2 
       AND current.contact_viewer_relationship != 2;

    -- Handle the case where the entire item no longer exists in the current database
    SELECT id
    FROM previous.contacts
    WHERE id NOT IN (SELECT id FROM current.contacts)
       AND contact_viewer_relationship = 2;

    DETACH DATABASE current;
    DETACH DATABASE previous;
EOF
)
fi

new_friends_output=""
if [ "$action" = "new" ] || [ "$action" = "both" ]; then
    echo -e "\nFinding new friends..."
    new_friends_output=$(sqlite3 <<EOF
    ATTACH DATABASE '$before_db' AS previous;
    ATTACH DATABASE '$after_db' AS current;

    -- Find new ids that have contact_viewer_relationship = 2
    SELECT id
    FROM current.contacts
    WHERE id NOT IN (SELECT id FROM previous.contacts)
      AND contact_viewer_relationship = 2;

    DETACH DATABASE current;
    DETACH DATABASE previous;
EOF
)
fi


echo

if [ -n "$unfriend_output" ] || [ -n "$new_friends_output" ]; then
            
    if [ -n "$unfriend_output" ]; then # Check if there are any removed or changed relationships
        echo -e "\n.·´¯(>▂<)´¯·. You got unfriended (╥_╥)"
        echo "$unfriend_output" | while read -r id; do
            name=$(sqlite3 "$before_db" "SELECT name FROM contacts WHERE id = '$id';") # Use this if you only want to show the name, instead of the line below.
            #name=$(sqlite3 -header -line "$before_db" "SELECT * FROM contacts WHERE id = '$id';") # Use this if you want to show ALL columns, instead of the line above.
            if [ -n "$name" ]; then
                echo -e "\nFriend: $name\nOpening https://www.facebook.com/$id"
            else
                echo -e "\nOpening https://www.facebook.com/$id"
            fi
            if [[ "$id" =~ ^[a-zA-Z0-9+/=]+$ ]]; then # Sanity check
                xdg-open "https://www.facebook.com/$id" & # Open URL in the default web browser
            else # Now id is only LONG_INT, but just in case it becomes Base64
                echo "Skipping invalid ID: $id. Only Base64 encoded or numeric IDs are allowed."
            fi
        done
    fi
        
    if [ -n "$new_friends_output" ]; then
        echo -e "\n(ノ^_^)ノ New friend detected! ヘ(^_^ヘ):"
        echo "$new_friends_output" | while read -r id; do
            name=$(sqlite3 "$after_db" "SELECT name FROM contacts WHERE id = '$id';") # Use this if you only want to show the name, instead of the line below.
            #name=$(sqlite3 -header -line "$after_db" "SELECT * FROM contacts WHERE id = '$id';") # Use this if you want to show ALL columns, instead of the line above.
            if [ -n "$name" ]; then
                echo -e "\nFriend: $name\nOpening https://www.facebook.com/$id"
            else
                echo -e "\nOpening https://www.facebook.com/$id"
            fi
            if [[ "$id" =~ ^[a-zA-Z0-9+/=]+$ ]]; then # Sanity check
                xdg-open "https://www.facebook.com/$id" &
            else # Now id is only LONG_INT, but just in case it becomes Base64
                echo "Skipping invalid ID: $id. Only Base64 encoded or numeric IDs are allowed."
            fi
        done
    fi
    
else
    if [ "$action" = "both" ]; then
        echo -e "\nNobody unfriended you nor added you as a new friend."
    elif [ "$action" = "removed" ]; then
        echo -e "\nNobody unfriended you."
    elif [ "$action" = "new" ]; then
        echo -e "\nNobody added you as a new friend."
    fi
    echo "Prompt to remove the new database you just pulled (y/n):"
    rm -i -- "$after_db"
fi

# Clean up any remaining WAL and SHM files just in case
# Ensure there is no `exit 1` after the database is created but before this point
echo "Cleaning up generated -WAL and -SHM files from sqlite3."
if [ -e "${before_db}-wal" ]; then
    rm -- "${before_db}-wal"
fi
if [ -e "${before_db}-shm" ]; then
    rm -- "${before_db}-shm"
fi
if [ -e "${after_db}-wal" ]; then
    rm -- "${after_db}-wal"
fi
if [ -e "${after_db}-shm" ]; then
    rm -- "${after_db}-shm"
fi




