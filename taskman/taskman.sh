#!/bin/bash

# The first parameter is the path to the task file
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <task_file>"
    exit 1
fi

task_file="$1"

# Initialize history array and file
declare -a cmd_history
history_file="/tmp/task_manager_history"

# Load history from file if it exists
if [ -f "$history_file" ]; then
    while IFS= read -r line; do
        cmd_history+=("$line")
    done < "$history_file"
    history_index=${#cmd_history[@]}
    # Load the history into the current session
    history -r "$history_file"
fi

display_tasks() {
    local awk_condition="$1"
    awk '
        BEGIN {
            FS=" ";  # Set field separator to space
            NUM_COLOR="\033[33m";
            FOCUS_COLOR="\033[38;2;114;176;125m\033[1m";
            RESET="\033[0m";
            no_tag_found=1;  # Flag to check if any tag is found
        }
        {
            if ($0 ~ /^[[:space:]]/) {
                # This is a detail line, add to the current item
                current_item = current_item "\n    " $0;
            } else {
                # Process the previous item if it exists
                if (current_item != "") {
                    if (item_matches) process_item(current_item);
                }
                # Start a new item
                current_item = $0;
                item_matches = '"$awk_condition"';
                no_tag_found = 1;  # Reset flag for new task
            }
        }
        function process_item(item) {
            no_tag_found = 1;
            split(item, lines, "\n");
            for (i in lines) {
                if (i == 1) {  # Main task line
                    split(lines[i], fields);
                    for (j in fields) {
                        if (fields[j] ~ /^@[a-zA-Z0-9\-]+$/) {  # Check if the field is a tag without '='
                            tag = substr(fields[j], 2);  # Remove '@' from the tag
                            if (!(tag in groups)) groups[tag] = "";
                            groups[tag] = groups[tag] sprintf(NUM_COLOR "%3d" RESET " | %s\n", NR-(split(item,dummy,"\n")), item);
                            last_group = tag;
                            no_tag_found = 0;
                        }
                    }
                    if (no_tag_found) {
                        if (!("Unlabeled" in groups)) groups["Unlabeled"] = "";
                        groups["Unlabeled"] = groups["Unlabeled"] sprintf(NUM_COLOR "%3d" RESET " | %s\n", NR-(split(item,dummy,"\n")), item);
                        last_group = "Unlabeled";
                    }
                }
            }
        }
        END {
            # Process the last item if it exists
            if (current_item != "") {
                if (item_matches) process_item(current_item);
            }
            for (g in groups) {
                if (g != "Unlabeled") {
                    print "      " FOCUS_COLOR "@" g ":" RESET;
                    print groups[g];
                }
            }
            if ("Unlabeled" in groups) {
                print "      " FOCUS_COLOR "Unlabeled:" RESET;
                print groups["Unlabeled"];
            }
        }
    ' "$task_file"
}

paginate() {
    local tasks=("$@")
    local terminal_lines=$(tput lines)
    local header_lines=4
    local page_size=$((terminal_lines - header_lines))
    local total_tasks=${#tasks[@]}
    local total_pages=$(( (total_tasks + page_size - 1) / page_size ))
    local current_page=1

    while true; do
        clear_screen
        echo "Tasks Page $current_page/$total_pages"
        start_index=$(( (current_page - 1) * page_size ))
        end_index=$(( start_index + page_size ))

        for (( i=start_index; i<end_index && i<total_tasks; i++ )); do
            echo "${tasks[i]}"
        done

        echo -e "\nCommands: [n]ext, [p]revious, [q]uit"
        read -n 1 -s command
        case $command in
            n)
                if [ $current_page -lt $total_pages ]; then
                    ((current_page++))
                fi
                ;;
            p)
                if [ $current_page -gt 1 ]; then
                    ((current_page--))
                fi
                ;;
            q)
                break
                ;;
        esac
    done
}

clear_screen() {
    echo -ne "\033[2J\033[H"
}

set_tag() {
    local tag="$1"
    shift
    local line_numbers=("$@")

    # Read the tasks file into an array
    tasks=()
    while IFS= read -r line; do
        tasks+=("$line")
    done < "$task_file"

    for line in "${line_numbers[@]}"; do
        if [[ "$line" =~ ^[0-9]+$ ]] && [ "$line" -le "${#tasks[@]}" ]; then
            # Read the existing line
            task="${tasks[line-1]}"
            if [[ "$tag" == *=* ]]; then
                # Handle tags with '=' (key=value)
                key="${tag%%=*}"
                value="${tag#*=}"
                if [[ "$task" =~ $key= ]]; then
                    # Update existing tag
                    task=$(echo "$task" | sed -E "s/$key=[^ ]+/$key=$value/")
                else
                    # Add new tag
                    task="$task $tag"
                fi
            else
                # Handle simple tags
                if [[ ! "$task" =~ $tag ]]; then
                    task="$task $tag"
                fi
            fi
            # Update the task in the array
            tasks[line-1]="$task"
        else
            echo "Invalid line number: $line"
        fi
    done

    # Write the updated tasks back to the tasks file
    printf "%s\n" "${tasks[@]}" > "$task_file"
}

# Main loop
while true; do
    read -e -p "task_manager> " cmd

    clear_screen

    # Save command to history
    if [[ -n "$cmd" ]]; then
        cmd_history+=("$cmd")
        history_index=${#cmd_history[@]}
        printf "%s\n" "$cmd" >> "$history_file"
        history -s "$cmd"
    fi

    case $cmd in
        "list"*)
            if [ "$cmd" = "list" ]; then
                # No search condition provided, use default
                awk_condition="/.*/"
            else
                # Use the provided search condition
                awk_condition="${cmd#list }"  # Remove "list " from the beginning
            fi

            # Capture the output of display_tasks into an array
            tasks=()
            while IFS= read -r line; do
                tasks+=("$line")
            done < <(display_tasks "$awk_condition")

            paginate "${tasks[@]}"
            ;;
        "add "*)
            echo "${cmd:4}" >> "$task_file"  # Append new task
            ;;
        "set "*)
            args=($cmd)
            tag="${args[1]}"
            line_numbers=("${args[@]:2}")
            set_tag "$tag" "${line_numbers[@]}"
            ;;
        "history")
            for i in "${!cmd_history[@]}"; do
                echo "$i: ${cmd_history[$i]}"
            done
            ;;
        "quit")
            break
            ;;
        *)
            echo "Unknown command"
            ;;
    esac
done
