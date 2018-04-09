#!/bin/bash
DARKNET_FOLDER=$1
VIDEO=$2
# TODO:
# [ ]: Logic to prevent bad args
# [ ]: Defaults everywhere
# [ ]: List of Videos
# [ ]: Images

printf "Currently untested DO NOT LET RUN!\r"
exit 0

PREFILE="./.currentFrame.png"

# Download & Make stuff 
pushd $DARKNET_FOLDER
[[ -ne ./darknet ]] && make
[[ -ne ./yolov2-tiny.weights ]] && wget https://pjreddie.com/media/files/yolov2-tiny.weights
popd

if [[ "$(uname)" == "Linux" ]]; then
    if [[ -ne /dev/ram1 ]]; then
        ME=$(whoami)
        sudo mkfs tmpfs /dev/ram1 8M
        sudo mkdir /tmp/tmp.ramcache -p
        sudo mount /dev/ram1 /tmp/tmp.ramcache
        sudo chown $ME:$ME /tmp/tmp.ramcache -R
        PREFILE="/tmp/tmp.ramcache/.currentFrame.png"
    fi
fi

coproc DARK { # then the command; } >/dev/null

secondsMax=$(mediainfo $2 --Inform="General;%Duration%")
startTime=$(date +%s)
cat <<END > $2.json
{ "file": "$2",
  "timeTaken": "N/A GTFO",
  "tags": [
END
for seconds in {0..$secondsMax}; do
    echo $seconds
    ffmpeg -ss $seconds -vframes 1 $2 $PREFILE

    echo "$PREFILE" >&"${DARK[1]}"

    while [[ -ne $DARKNET_FOLDER/predictions.json ]]; do
        sleep 0.2s
    done

    [[ "$seconds" != "0" ]] && echo "," >> $2.json
    sed -e "s/\[/\{\"timestamp\":${seconds},\"array\":[/g;s/\]/\]\}/g" predictions.json >> $2.json
    rm predictions.json
done
echo "]}" >> $2.json
endTime=$(date +%s)
exec {DARK[1]}>&-
sed "s/N\/A GTFO/$(bc -l <<<\"$endTime - $startTime\")/g"
