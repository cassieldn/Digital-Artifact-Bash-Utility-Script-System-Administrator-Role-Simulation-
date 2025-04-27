#!/bin/bash

pid=$BASHPID

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
directory="$script_dir/_Directory"

uuid_file="$script_dir/uuid.txt"
report_file="$script_dir/report.txt"
log_file="$script_dir/logfile.log"

# the username of the user logged in at the time 
username=$(whoami)
# Get the current timestamp
timestamp=$(date)

# Log info to logfile
echo -e "\nTimestamp: $timestamp" >> $log_file
echo "User: $username" >> $log_file
echo "PID: $pid" >> $log_file
echo "Args: ${*@Q}" >> $log_file

gen_uuid1() {
    local timestamp=$(date +%s)
    local timestamp_hex=$(printf "%x" $((timestamp * 10000000 + 122192928000000000)))
    local clock_seq=$(openssl rand -hex 2)
    local clock_seq_var=$(printf '%x' $(( ( 0x${clock_seq:0:2} & 0x3F ) | 0x80 )))${clock_seq:2}
    local time_low=${timestamp_hex:7}
    local time_mid=${timestamp_hex:3:4}
    local time_hi_and_version=1${timestamp_hex:0:3}
    local node=$(openssl rand -hex 6)
    printf "%s-%s-%s-%s-%s\n" \
            $time_low $time_mid $time_hi_and_version $clock_seq_var $node
}

gen_uuid4() {
    bytes=$(openssl rand -hex 16)
    uuid="${bytes:0:8}-${bytes:8:4}-4${bytes:13:3}-$(( 0x${bytes:16:2} & 0x3))${bytes:18:3}-${bytes:20:12}"
    echo "$uuid"
}

handle_argument() {
    case $1 in
        -1)
            new_uuid=$(gen_uuid1)
            if grep -q "$new_uuid" "$uuid_file"; then
                echo "Collision detected: UUID already exists."
                exit 1
            fi
            echo -e "$(date)\t$new_uuid" >> "$uuid_file"
            ;;
        -4)
            new_uuid=$(gen_uuid4)
            if grep -q "$new_uuid" "$uuid_file"; then
                echo "Collision detected: UUID already exists."
                exit 1
            fi
            echo -e "$(date)\t$new_uuid" >> "$uuid_file"
            ;;
        -p)
            cat "$uuid_file"
            ;;
        -g)
            output=$(generate_report)
            echo "$output" > "$report_file"
            ;;
        *)
            echo "Invalid argument."
            exit 1
            ;;
    esac

    echo "$new_uuid"
}

find_shortest_longest_filename() {
    find "$1" -type f -print0 | awk -v RS='\0' 'NR==1 {shortest=length($0); longest=length($0)} {if (length($0) < shortest) shortest=length($0); if (length($0) > longest) longest=length($0)} END {print shortest, longest}'
}

summarise_directory() {
    dir="$1"
    declare -A file_counts
    declare -A file_sizes
    total_size=0
    for file in "$dir"/*; do
        if [ -f "$file" ]; then
            extension="${file##*.}"
            ((file_counts[$extension]++))
            size=$(du -sb "$file" | cut -f1)
            file_sizes[$extension]=$((file_sizes[$extension] + size))
            total_size=$((total_size + size))
        fi
    done
    echo "Summary for directory: $dir"
    echo "--------------------------------"
    for ext in "${!file_counts[@]}"; do
        echo "Files with extension .$ext: ${file_counts[$ext]}"
        echo "Collective size: $(numfmt --to=iec ${file_sizes[$ext]})"
        echo "--------------------------------"
    done
    echo "Total size: $(numfmt --to=iec $total_size)"
}

generate_report() {
    directories=($(find "$directory"/* -type d))
    for dir in "${directories[@]}"; do
        if [ -d "$dir" ]; then
            echo "Directory: $dir"
            echo "File Types and Collective Size:"
            summarise_directory "$dir"
            echo "Shortest and Longest Filename Length:"
            find_shortest_longest_filename "$dir"
            echo ""
        fi
    done
}

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 -1|-4|-g|-p"
    exit 1
fi

handle_argument "$1"
