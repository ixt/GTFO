#!/bin/bash
WORKINGDIR=$(dirname $0)
OUTPUTAFFIX=".yolov2tiny"
PREFILE="./.currentFrame.png"
LOCKFILE="$WORKINGDIR/.lock"

# Make sure to put checks in place 
clean_up(){
    rm -f "$LOCK_FILE"
    echo "Leaving GTFO"
    exit 1
}

trap clean_up SIGHUP SIGINT SIGTERM

pushd $WORKINGDIR
# Download & Make stuff 
[[ ! -f ./darknet/README.md ]] && git submodule init && git submodule update
pushd darknet
[[ ! -f ./darknet ]] && make
[[ ! -f ./yolov2-tiny.weights ]] && wget https://pjreddie.com/media/files/yolov2-tiny.weights
popd

# If you're running linux then make a ram disk to write the images to
if [[ "$(uname)" == "Linux" ]]; then
    printf "Running linux \n"
    if [[ ! -f /dev/ram1 ]]; then
        ME=$(whoami)
        sudo mkfs -q /dev/ram1 8192
        sudo mkdir /tmp/tmp.ramcache -p
        sudo mount /dev/ram1 /tmp/tmp.ramcache
        sudo chown $ME:$ME /tmp/tmp.ramcache -R
        PREFILE="/tmp/tmp.ramcache/.currentFrame.png"
    fi
    if [[ -f /dev/ram1 ]]; then 
        PREFILE="/tmp/tmp.ramcache/.currentFrame.png"
    fi
    echo $PREFILE
fi

# Coprocess the darknet interactive terminal
coproc DARK { \
    pushd $WORKINGDIR/darknet;
    ./darknet detect \
    cfg/yolov2-tiny.cfg \
    yolov2-tiny.weights ; \
    popd; \
} &2>&1 >/dev/null

while read VIDEO; do
LOCKFILE="$VIDEO.lock"
[[ -f "$VIDEO.lock" ]] && break
touch "$VIDEO.lock"

secondsMax=$(mediainfo "$VIDEO" --Inform="General;%Duration%" \
    | xargs -I@ echo "scale=0;@ / 1000" \
    | bc -l )

echo "" > "$WORKINGDIR/darknet/predictions.json"

startTime=$(date +%s)

cat <<END > "$VIDEO$OUTPUTAFFIX.json"
{ "file": "$VIDEO",
  "timeTaken": "N/A GTFO",
  "tags": [
END

for seconds in $(seq 0 $secondsMax); do
    printf "$seconds / $secondsMax \n"
    ffmpeg -hwaccel vaapi -hide_banner -loglevel fatal -ss $seconds -i "$VIDEO" -vframes 1  "$PREFILE" -y

    echo "$PREFILE" >&"${DARK[1]}"

    while :; do
        grep -q -F "[" "$WORKINGDIR/darknet/predictions.json" && break
    done

    [[ "$seconds" != "0" ]] && echo "," >> "$VIDEO$OUTPUTAFFIX.json"
    cat "$WORKINGDIR/darknet/predictions.json"
    sed -e "s/\[/\{\"timestamp\":${seconds},\"array\":[/g;s/\]/\]\}/g" "$WORKINGDIR/darknet/predictions.json" >> "$VIDEO$OUTPUTAFFIX.json"
    printf "" > "$WORKINGDIR/darknet/predictions.json"
done

echo "]}" >> "$VIDEO$OUTPUTAFFIX.json"
endTime=$(date +%s)
echo $startTime $endTime
runningTime=$(bc -l <<< "$endTime - $startTime")
sed -i -e "s/N\/A GTFO/$runningTime/g" "$VIDEO$OUTPUTAFFIX.json"

rm -f "$VIDEO.lock"

done < <(echo "$1")

popd
