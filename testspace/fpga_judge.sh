echo -e "\n================"
cat test.out
echo -e "\n================"

if [ ! -f test.ans ]; then
    echo "test.ans not found, exiting."
    exit 0
fi

diff -Z test.ans test.out
if [ $? -eq 0 ]; then
    echo -e "\e[32mAccepted\e[0m"
    exit 0
else
    echo -e "\e[31mWrong Answer\e[0m"
    exit 1
fi