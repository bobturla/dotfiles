#!/bin/bash
# functions.sh
# misc functions to help with your workstation.

# Writes a log to ~/.workstation.log/
# Usage: echo <message> | log [<logfile name>]
# eg: echo "hello world" | log
# eg: echo "hello world" | log mylog.log
log()
{
    local message
    # Read message from STDIN
    read message
    # If dir does not exist, create it
    [ -d ~/.workstation.log ] || mkdir ~/.workstation.log
    # Set provide default value for first argument
    [ -z "$1" ] && log_basename='workstation.log' || log_basename="$1"
    # Concatenate dir with basename
    local log_path=~/.workstation.log/"$log_basename"
    # Create logfile if it doesn't exist
    touch "$log_path"
    # Get current time in ISO8601 format
    # eg: 2014-08-29T19:01:46+10:00
    local date=$(date +%F\T%T%z | sed 's/^.\{22\}/&:/')
    # Get process ID
    local pid=$$
    # Append message to log file
    echo "$date $pid $message" >> "$log_path"
}

# Backs up a file (creates a copy in the same dir with <name>.bak-<timestamp>)
# Usage: backup /path/to/file
backup()
{
    cp "$1" "$1.bak-$(date --utc +%Y%m%d_%H%M%SZ)"
}

backup_remove()
{
    if [ -e "$1" ]
    then
        backup "$1"
        rm "$1"
    fi
}

# Executes a command repeatedly
# usage: repeat <command> [<frequency in seconds>]
#   CTRL+c to quit
# eg: repeat date
# Note that this is similar to `watch`
repeat()
{
    echo "TODO. fix me"; return
    local command=$1           # command is first arg
    local frequency=${2:-1}    # frequency is second arg or "1"

    clear

    trap ctrl_c INT            # catch ctrl+c keypress
    function ctrl_c
    {
        clear
        tput cnorm              # put the cursor back to normal
        return
    }

    while [ true ]              # Repeat forever
    do
        tput civis              # hide the cursor
        tput cup 0 0            # put cursor at top-left
        $command                # execute the command
        sleep $frequency        # wait for frequency
    done
}

# Watches a directory (recursively) for changes
# If any files within the directory change, executes command
# Usage: execute_on_change <dir> <command>
# eg: execute_on_change /tmp "echo yep"
execute_on_change()
{
    # see also: https://gist.github.com/senko/1154509
    local path="$1"
    local command="$2"
    local current_hash=""
    local new_hash=""
    while [[ true ]]
    do
        new_hash="$(find "$path" -type f | md5sum)"
        if [[ $old_hash != $new_hash ]]
        then           
            $command
            old_hash=$new_hash
        fi
        sleep 2
        echo "hash: $new_hash"
    done
}

# Displays "Press [ENTER] to cancel..."
# Returns:
#   true after a 4 second timeout
#   false if the user presses enter
# eg:
#   echo "about to do the thing"
#   if enter_to_cancel
#   then
#       echo "doing the thing"
#   fi
enter_to_cancel()
{
    # Display the message
    echo -n "Press [ENTER] to cancel"
    # Give them some time to read
    local i
    for i in 1 2 3 4
    do
        # If it's not the first second, display a dot
        [ "$i" -gt 1 ] && echo -n "."
        # Wait 1 second, if the user enters something return false
        read -t 1 && return 1
    done
    # end the line
    echo
    # nothing was pressed, return true
    return 0
}

# Get internet IP address
getip_public()
{
    curl http://ipecho.net/plain
    echo
}

# Get local IP address
# Usage: getip [<interface name>]
getip()
{
    # interface provided as $1, defaults to "eth0"
    local interface=${1:-eth0}
    ifconfig "$interface" | grep -oP '(?<=inet addr:).*?(?= )'
    # -o                    # output the match
    # -P                    # use pearl regex
    # (?<=PATTERN)          # begin selection after this pattern
    # .*?                   # select everything until first match
    # (?=PATTERN)           # end selection before this pattern
}

# Sets a static IP address
# Backs up existing interfaces file
# Usage: setip <fourth IP tuplet> [<interface>]
# eg: setip 99
# eg: setip 50 wlan0
setip()
{
    local path="/etc/network/interfaces"
    # TODO: Error if no $1 is passed

    local interface=${2:-eth0}
    # TODO:
    #   - detect the list of interfaces
    #   - if only 1; use that; otherwise throw error
    #   ifconfig -s -a | awk '{print $1}'

    # Get the existing IP address parts
    local p1 p2 p3 p4
    read p1 p2 p3 p4 <<< $(getip "$interface" | tr "." "\n")

    # Set the fourth tuplet to that provided
    p4=$1

    # Backup existing file
    sudo cp "$path"{,.bak}

    # Write new file
    sudo sh -c "echo 'auto lo'                              > $path"
    sudo sh -c "echo 'iface lo inet loopback'              >> $path"
    sudo sh -c "echo ''                                    >> $path"
    sudo sh -c "echo 'auto $interface'                     >> $path"
    sudo sh -c "echo 'iface $interface inet static'        >> $path"
    sudo sh -c "echo '    address $p1.$p2.$p3.$p4'         >> $path"
    sudo sh -c "echo '    network $p1.$p2.$p3.0'           >> $path"
    sudo sh -c "echo '    netmask 255.255.255.0'           >> $path"
    sudo sh -c "echo '    broadcast $p1.$p2.$p3.255'       >> $path"
    sudo sh -c "echo '    dns-nameservers $p1.$p2.$p3.255' >> $path"
    sudo sh -c "echo '    gateway $p1.$p2.$p3.1'           >> $path"
    echo "IP address $p1.$p2.$p3.$p4 written to $path"

    # Restart the network
    # TODO: Only restart specific interface
    echo "Restarting network"
    if enter_to_cancel
    then
        sudo ifdown -a
        sudo ifup -a
    fi
}

# Creates a new branch
# Usage: git branch <branchname>
git_branch()
{
    echo "git checkout -b $1"
    git checkout -b $1
    
    echo "git push -u origin $1"
    git push -u origin $1
}

# Run a program in the background
# Usage: run_in_background <command>
run_in_background()
{
    $@ > /dev/null 2>&1 &
    echo "Job running in background with pid: $!"
}

# Shortens a GitHub URL
# Usage: github_shortenurl <github url> [<code>]
github_shortenurl()
{
    # TODO:
    # - Warn if url looks like a commit instead of a head
    # - Warn if no /raw part on the end
    # - Output only the new URL if it worked
    
    local long_url short_url code orl_arg code_arg response
    
    if [ -n "$1" ]
    then
        long_url="$(echo $1 | sed 's/githubusercontent/github/g')"
    else
        describe_function "$FUNCNAME"
        return 1
    fi
    
    if [ -n "$2" ]
    then
        curl -o- -i -s http://git.io -F "url=$long_url" -F "code=$2"
    else
        curl -o- -i -s http://git.io -F "url=$long_url"
    fi
    
    echo 
}

# Set the terminal title
set_term_title()
{
    echo -ne "\033]0;$1\007"
}

# Clone from github
# Usage: github_clone username/repo
github_clone()
{
    git clone git@github.com:/$1.git
}

# Clone from bitbucket
# Usage: bitbucket_clone username/repo
bitbucket_clone()
{
    git clone git@bitbucket.com:/$1.git
}


# Opens a google-chrome browser and googles for the query
# Usage: google <query>
# eg: google shell scripting
google()
{
    local command="google-chrome https://www.google.com.au/search?q=$1&btnl=1"
    run_in_background "$command"
}

# # Copies the current terminal line
# # Bound to ALT+C
# copy_current_line()
# {
#     local current_line="${READLINE_LINE:0:$READLINE_POINT}${CLIP}${READLINE_LINE:$READLINE_POINT}"
#     echo -n "$current_line" | xclip
# }
# bind -m emacs -x '"\ec": copy_current_line' || echo "unable to bind for copy-line"

# Copies the last command executed
copy_last_command()
{
    fc -ln -1 | sed 's/^ *//' | xclip                            # copies to middle-click-paste
    # fc -ln -1 | sed 's/^ *//' | xclip -selection clipboard     # copies to regular paste
}

# View active network connections
view_network()
{
    lsof -i
}

# Displays a hash of a directory recursively
# Usage: hashdir <path/to/dir>
hashdir()
{
    local dir="$1"
    find "$dir" -type f -exec md5sum {} + | awk '{print $1}' | sort | md5sum
}
