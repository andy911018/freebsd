#!/bin/sh

# 打印 PATH 以進行調試
echo "Current PATH: $PATH"

show_help() {
    echo "Usage: hw2.sh -p TASK_ID -t TASK_TYPE [-h]"
    echo "Available Options:"
    echo "  -p: Task id"
    echo "  -t: JOIN_NYCU_CSIT | MATH_SOLVER | CRACK_PASSWORD: Task type"
    echo "  -h: Show the script usage"
}

TASK_ID=""
TASK_TYPE=""

# 檢查依賴項
echo "Checking dependencies..."
for cmd in curl jq; do
    echo "Checking $cmd..."
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd is not installed or not in PATH." >&2
        exit 1
    fi
done
echo "All dependencies are satisfied."

# 解析參數
while getopts ":p:t:h" opt; do
  case $opt in
    p)
      TASK_ID="$OPTARG"
      ;;
    t)
      TASK_TYPE="$OPTARG"
      ;;
    h)
      show_help
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      show_help
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      show_help
      exit 1
      ;;
  esac
done

# 檢查必需的參數
if [ -z "$TASK_ID" ] || [ -z "$TASK_TYPE" ]; then
    echo "Task ID and Task Type are required." >&2
    show_help
    exit 1
fi

# 設置 PATH（根據需要調整）
# export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

get_task() {
    RESPONSE=$(curl -s -X GET "http://10.113.0.253/tasks/$TASK_ID" -H "Content-Type: application/json")
    echo "Response from get_task: $RESPONSE"  # 調試輸出

    # 檢查是否有錯誤字段
    ERROR_FIELD=$(echo "$RESPONSE" | jq -r '.error')
    if [ "$ERROR_FIELD" != "null" ] && [ -n "$ERROR_FIELD" ]; then
        echo "Error fetching task: $ERROR_FIELD" >&2
        exit 1
    fi

    # 提取 PROBLEM
    PROBLEM=$(echo "$RESPONSE" | jq -r '.problem')
}

submit_answer() {
    ANSWER="$1"
    RESPONSE=$(curl -s -X POST "http://10.113.0.253/tasks/$TASK_ID/submit" \
        -H "Content-Type: application/json" \
        -d "{\"answer\":\"$ANSWER\"}")
    echo "Response from submit_answer: $RESPONSE"
}

solve_math() {
    PROBLEM="$1"
    # 假設 PROBLEM 格式為 "number1 + number2"
    NUMBER1=$(echo "$PROBLEM" | awk '{print $1}')
    OPERATOR=$(echo "$PROBLEM" | awk '{print $2}')
    NUMBER2=$(echo "$PROBLEM" | awk '{print $3}')

    # 只處理加法
    if [ "$OPERATOR" = "+" ]; then
        ANSWER=$(expr "$NUMBER1" + "$NUMBER2")
    else
        echo "Unsupported operator: $OPERATOR" >&2
        exit 1
    fi

    submit_answer "$ANSWER"
}

solve_join_nycu_csit() {
    submit_answer "I Love NYCU CSIT"
}

solve_crack_password() {
    PROBLEM="$1"
    # 使用 ROT13 轉換
    ANSWER=$(echo "$PROBLEM" | tr 'A-Za-z' 'N-ZA-Mn-za-m')
    submit_answer "$ANSWER"
}

# 獲取任務詳細信息
get_task
echo "Problem: $PROBLEM"  # 調試輸出

# 根據 TASK_TYPE 執行相應的解決函數
case "$TASK_TYPE" in
    "MATH_SOLVER")
        solve_math "$PROBLEM"
        ;;
    "JOIN_NYCU_CSIT")
        solve_join_nycu_csit
        ;;
    "CRACK_PASSWORD")
        solve_crack_password "$PROBLEM"
        ;;
    *)
        echo "Invalid task type: $TASK_TYPE" >&2
        exit 1
        ;;
esac


