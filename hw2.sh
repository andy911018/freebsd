#!/bin/bash

show_help() {
    echo "Usage: hw2.sh -p TASK_ID -t TASK_TYPE [-h]"
    echo "Available Options:"
    echo "-p: Task id"
    echo "-t: JOIN_NYCU_CSIT | MATH_SOLVER | CRACK_PASSWORD: Task type"
    echo "-h: Show the script usage"
}

TASK_ID=""
TASK_TYPE=""

# 檢查依賴項
for cmd in curl jq; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed." >&2
        exit 1
    fi
done

while getopts ":p:t:h" opt; do
  case $opt in
    p) TASK_ID=$OPTARG ;;
    t) TASK_TYPE=$OPTARG ;;
    h) show_help; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; show_help; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; show_help; exit 1 ;;
  esac
done

if [ -z "$TASK_ID" ] || [ -z "$TASK_TYPE" ]; then
    echo "Task ID and Task Type are required." >&2
    show_help
    exit 1
fi

get_task() {
    RESPONSE=$(curl -s -X GET http://10.113.0.253/tasks/$TASK_ID -H "Content-Type: application/json")
    if [ "$(echo "$RESPONSE" | jq -r '.error')" != "null" ]; then
        echo "Error fetching task: $(echo "$RESPONSE" | jq -r '.error')" >&2
        exit 1
    fi
    PROBLEM=$(echo "$RESPONSE" | jq -r '.problem')
}

submit_answer() {
    ANSWER=$1
    RESPONSE=$(curl -s -X POST http://10.113.0.253/tasks/$TASK_ID/submit \
        -H "Content-Type: application/json" \
        -d "{\"answer\":\"$ANSWER\"}")
    echo "$RESPONSE"
}

solve_math() {
    PROBLEM=$1
    # 假設 PROBLEM 格式為 "number1 + number2"
    ANSWER=$(echo "$PROBLEM" | awk '{print $1 + $3}')
    submit_answer "$ANSWER"
}

solve_join_nycu_csit() {
    submit_answer "I Love NYCU CSIT"
}

solve_crack_password() {
    PROBLEM=$1
    ANSWER=$(echo "$PROBLEM" | tr 'A-Za-z' 'N-ZA-Mn-za-m')
    submit_answer "$ANSWER"
}

# 獲取任務詳細信息
get_task

case $TASK_TYPE in
    "MATH_SOLVER") solve_math "$PROBLEM" ;;
    "JOIN_NYCU_CSIT") solve_join_nycu_csit ;;
    "CRACK_PASSWORD") solve_crack_password "$PROBLEM" ;;
    *) echo "Invalid task type" >&2; exit 1 ;;
esac

