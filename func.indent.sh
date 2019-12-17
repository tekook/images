INDENT=0
function echoIndent {
    for((i=1;i<=$INDENT;i++));
    do
        printf "\t"
    done;
    printf $1
    printf "\n"
}