## Facebook Unfriend and New Friend Checker

This Bash script utilizes adb to pull the Facebook database from a rooted Android/emulator, compares snapshots to identify unfriended and new friends, and opens a web browser for each friend. No need to scroll through your entire friends list; you get instant results.

---
### Features  

- Track Unfriends: Identify who has removed you from their friends list.
- Discover New Friends: See who has recently added you.

---
### Screenshot:

 ![Android](/images/demo_screenshot.png?raw=true "Sample output")

---
### Prerequisites  

- A Linux system with ADB, Bash, SQLite3, and xdg-open installed.
- A rooted Android emulator or phone with USB debugging enabled and connected to your Linux system.
- Facebook app logged in on the emulator or phone. If you have just installed and logged into the Facebook app, wait approximately 30 minutes to ensure the full database is available before running this script. In the worst-case scenario, you may need to kill the app and then relaunch it after a long time.

---
### Installation  

Clone this repository to your local machine:

```
git clone https://github.com/limkokhole/Facebook-Unfriend-and-New-Friend-Checker.git
cd fb-unfriend-checker
```

---
### Usage  
#### Ensure your device meets the prerequisites, then run the script with the following command:  

```
    bash fb_unfriend_checker.sh <fb_user_id> [check_type]
```

- fb_user_id: Your numerical Facebook user ID, which can be found in the URL when viewing your profile or using the "View As" feature.
- check_type (optional): Type of check to perform. Options are:
        unfriend (default)
        new_friend
        both

#### Examples  

- To check for unfriends by default:
    
    `bash fb_unfriend_checker.sh 1202604355`

- To specify the check type:

    `bash fb_unfriend_checker.sh 1202604355 both`

---
### Important Notes  

- Changes such as unfriending may take some time to reflect in the database.
