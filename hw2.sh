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

# Caesar Cipher 解密函數
caesar_decrypt() {
    encrypted_text="$1"
    shift="$2"
    decrypted_text=""

    i=1
    while [ $i -le ${#encrypted_text} ]; do
        char=$(echo "$encrypted_text" | cut -c $i)
        case "$char" in
            [A-Ma-m])
                decrypted_char=$(echo "$char" | tr 'A-Ma-m' 'N-Zn-za-m')
                ;;
            [N-Zn-z])
                decrypted_char=$(echo "$char" | tr 'N-Zn-z' 'A-Ma-m')
                ;;
            '{' | '}')
                decrypted_char="$char"
                ;;
            *)
                decrypted_char="$char"
                ;;
        esac
        decrypted_text="${decrypted_text}${decrypted_char}"
        i=$((i + 1))
    done

    echo "$decrypted_text"
}

solve_math() {
    PROBLEM="$1"
    # 檢查問題格式：a (+/-) b = c
    echo "$PROBLEM" | grep -E '^-?[0-9]+ [+\-] [0-9]+ = -?[0-9]+$' >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        submit_answer "Invalid problem"
        exit 0
    fi

    # 提取 a, operator, b, c
    a=$(echo "$PROBLEM" | awk '{print $1}')
    operator=$(echo "$PROBLEM" | awk '{print $2}')
    b=$(echo "$PROBLEM" | awk '{print $3}')
    c=$(echo "$PROBLEM" | awk '{print $5}')

    # 驗證範圍
    if [ "$a" -lt -10000 ] || [ "$a" -gt 10000 ]; then
        submit_answer "Invalid problem"
        exit 0
    fi

    if [ "$b" -lt 0 ] || [ "$b" -gt 10000 ]; then
        submit_answer "Invalid problem"
        exit 0
    fi

    if [ "$c" -lt -20000 ] || [ "$c" -gt 20000 ]; then
        submit_answer "Invalid problem"
        exit 0
    fi

    # 計算答案
    if [ "$operator" = "+" ]; then
        answer=$(expr "$a" + "$b")
    elif [ "$operator" = "-" ]; then
        answer=$(expr "$a" - "$b")
    else
        submit_answer "Invalid problem"
        exit 0
    fi

    # 驗證計算結果是否等於 c
    if [ "$answer" -ne "$c" ]; then
        submit_answer "Invalid problem"
        exit 0
    fi

    # 提交答案
    submit_answer "$answer"
}

solve_join_nycu_csit() {
    submit_answer "I Love NYCU CSIT"
}

solve_crack_password() {
    PROBLEM="$1"

    # 檢查問題格式是否包含 { 和 } 並符合基本格式
    echo "$PROBLEM" | grep -E '^NYCUNASA\{[A-Za-z]{16}\}$' >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        submit_answer "Invalid problem"
        exit 0
    fi

    # 提取加密部分（忽略 { 和 }）
    encrypted_part=$(echo "$PROBLEM" | sed 's/^NYCUNASA{//;s/}$//')

    # 嘗試所有可能的移位 1 到 13
    found=0
    shift=1
    while [ "$shift" -le 13 ]; do
        decrypted=$(caesar_decrypt "$encrypted_part" "$shift")
        # 構造完整明文
        plaintext="NYCUNASA{$decrypted}"
        # 檢查是否符合正則表達式
        echo "$plaintext" | grep -E '^NYCUNASA\{[A-Za-z]{16}\}$' >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            submit_answer "$plaintext"
            found=1
            break
        fi
        shift=$((shift + 1))
    done

    if [ "$found" -eq 0 ]; then
        submit_answer "Invalid problem"
    fi
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
