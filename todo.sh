#!/bin/bash

TODO_FILE='todos.json'

load_todos() {
    if [[ ! -f $TODO_FILE || ! -s $TODO_FILE ]]; then
        echo "[]" > $TODO_FILE
    fi
    cat $TODO_FILE
}

save_todos() {
    echo "$1" > $TODO_FILE
}

create_task() {
    todos=$(load_todos)
    task_id=$(echo "$todos" | jq '. | map(.id) | max + 1' 2>/dev/null)
    if [[ $task_id == null ]]; then
        task_id=1
    fi
    task=$(jq -n \
        --arg id "$task_id" \
        --arg title "$1" \
        --arg due_date "$2" \
        --arg description "$3" \
        --arg location "$4" \
        '{id: $id | tonumber, title: $title, description: $description, location: $location, due_date: $due_date, completed: false}')
    todos=$(echo "$todos" | jq --argjson task "$task" '. += [$task]')
    save_todos "$todos"
    echo "Task '$1' created with ID $task_id."
}

update_task() {
    todos=$(load_todos)
    task_id=$1
    title=$2
    description=$3
    location=$4
    due_date=$5
    completed=$6

    task=$(echo "$todos" | jq --arg id "$task_id" '.[] | select(.id == ($id | tonumber))')
    if [[ -z $task ]]; then
        echo "Task ID $task_id not found." >&2
        return
    fi

    if [[ -n $title ]]; then
        task=$(echo "$task" | jq --arg title "$title" '.title = $title')
    fi
    if [[ -n $description ]]; then
        task=$(echo "$task" | jq --arg description "$description" '.description = $description')
    fi
    if [[ -n $location ]]; then
        task=$(echo "$task" | jq --arg location "$location" '.location = $location')
    fi
    if [[ -n $due_date ]]; then
        task=$(echo "$task" | jq --arg due_date "$due_date" '.due_date = $due_date')
    fi
    if [[ -n $completed ]]; then
        task=$(echo "$task" | jq --argjson completed "$completed" '.completed = $completed')
    fi

    todos=$(echo "$todos" | jq --argjson task "$task" --arg id "$task_id" 'map(if .id == ($id | tonumber) then $task else . end)')
    save_todos "$todos"
    echo "Task ID $task_id updated."
}

delete_task() {
    todos=$(load_todos)
    task_id=$1
    todos=$(echo "$todos" | jq --arg id "$task_id" 'map(select(.id != ($id | tonumber)))')
    save_todos "$todos"
    echo "Task ID $task_id deleted."
}

show_task() {
    todos=$(load_todos)
    task_id=$1
    task=$(echo "$todos" | jq --arg id "$task_id" '.[] | select(.id == ($id | tonumber))')
    if [[ -z $task ]]; then
        echo "Task ID $task_id not found." >&2
    else
        echo "$task" | jq .
    fi
}

list_tasks() {
    todos=$(load_todos)
    date=$1
    completed=$(echo "$todos" | jq --arg date "$date" '[.[] | select(.due_date == $date and .completed == true)]')
    uncompleted=$(echo "$todos" | jq --arg date "$date" '[.[] | select(.due_date == $date and .completed == false)]')
    
    echo "Completed Tasks:"
    echo "$completed" | jq -r '.[] | "ID: \(.id) - Title: \(.title)"'
    
    echo -e "\nUncompleted Tasks:"
    echo "$uncompleted" | jq -r '.[] | "ID: \(.id) - Title: \(.title)"'
}

search_task() {
    todos=$(load_todos)
    title=$1
    found=$(echo "$todos" | jq --arg title "$title" '[.[] | select(.title | test($title; "i"))]')
    if [[ $(echo "$found" | jq '. | length') -eq 0 ]]; then
        echo "No tasks found with title containing '$title'."
    else
        echo "$found" | jq .
    fi
}

validate_date() {
    date -d "$1" +"%Y-%m-%d" > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Date must be in format YYYY-MM-DD" >&2
        exit 1
    fi
    echo "$1"
}

menu() {
    while true; do
        echo -e "\nTODO List Menu:"
        echo "1. Create task"
        echo "2. Update task"
        echo "3. Delete task"
        echo "4. Show task"
        echo "5. List tasks for a day"
        echo "6. Search tasks by title"
        echo "7. Exit"
        
        read -rp "Enter your choice (1-7): " choice
        
        case $choice in
            1)
                read -rp "Enter task title: " title
                read -rp "Enter due date (YYYY-MM-DD): " due_date
                read -rp "Enter task description (optional): " description
                read -rp "Enter task location (optional): " location
                due_date=$(validate_date "$due_date")
                create_task "$title" "$due_date" "$description" "$location"
                ;;
            2)
                read -rp "Enter task ID to update: " task_id
                read -rp "Enter new title (or leave blank to keep current): " title
                read -rp "Enter new description (or leave blank to keep current): " description
                read -rp "Enter new location (or leave blank to keep current): " location
                read -rp "Enter new due date (YYYY-MM-DD) (or leave blank to keep current): " due_date
                read -rp "Is the task completed? (yes/no/leave blank to keep current): " completed
                
                if [[ -n $due_date ]]; then
                    due_date=$(validate_date "$due_date")
                fi
                
                if [[ $completed == "yes" ]]; then
                    completed="true"
                elif [[ $completed == "no" ]]; then
                    completed="false"
                else
                    completed=""
                fi
                
                update_task "$task_id" "$title" "$description" "$location" "$due_date" "$completed"
                ;;
            3)
                read -rp "Enter task ID to delete: " task_id
                delete_task "$task_id"
                ;;
            4)
                read -rp "Enter task ID to show: " task_id
                show_task "$task_id"
                ;;
            5)
                read -rp "Enter date (YYYY-MM-DD): " date
                date=$(validate_date "$date")
                list_tasks "$date"
                ;;
            6)
                read -rp "Enter title to search for: " title
                search_task "$title"
                ;;
            7)
                echo "Exiting TODO List..."
                break
                ;;
            *)
                echo "Invalid choice. Please enter a number between 1 and 7."
                ;;
        esac
    done
}

menu

