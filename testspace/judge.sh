input_file="test.out.raw"

# 输出文件名
output_file="test.out"

# 忽略第一行，删除"IO:Return" 及之后的字符串，然后输出到新文件
sed '1d;s/IO:Return.*//g' "$input_file" | sed '${/^$/d;}' > "$output_file"

# echo "处理完成，结果已保存到 $output_file"
diff -Z test.ans test.out
if [ $? -eq 0 ]; then
    echo -e "\e[32mAccepted\e[0m"
else
    echo -e "\e[31mWrong Answer\e[0m"
fi