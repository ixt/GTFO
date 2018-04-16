#!/bin/bash
VIDEO=$1
WORKINGDIR=$(dirname $0)
# TODO:
# [ ]: Logic to prevent bad args
# [ ]: Defaults everywhere
# [ ]: List of Videos
# [ ]: Images

pushd $WORKINGDIR

PREFILE="./.currentFrame.png"

# Download & Make stuff 
[[ ! -f ./darknet/README.md ]] && git submodule init && git submodule update
pushd darknet
[[ ! -f ./darknet ]] && make
[[ ! -f ./yolov2-tiny.weights ]] && wget https://pjreddie.com/media/files/yolov2-tiny.weights
popd

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

coproc DARK { \
    pushd $WORKINGDIR/darknet;
    ./darknet detect \
    cfg/yolov2-tiny.cfg \
    yolov2-tiny.weights; popd; \
} >/dev/null

secondsMax=$(mediainfo $VIDEO --Inform="General;%Duration%" | xargs -I@ echo "scale=0;@ / 1000" | bc -l )
startTime=$(date +%s)
cat <<END > $VIDEO.json
{ "file": "$VIDEO",
  "timeTaken": "N/A GTFO",
  "tags": [
END
for seconds in $(seq 0 $secondsMax); do
    echo "$seconds / $secondsMax"
    ffmpeg -hide_banner -loglevel panic -ss $seconds -i $VIDEO -vframes 1 $PREFILE -y

    echo "$PREFILE" >&"${DARK[1]}"

    while [[ ! -f $WORKINGDIR/darknet/predictions.json ]]; do
        sleep 0.2s
    done

    [[ "$seconds" != "0" ]] && echo "," >> $VIDEO.json
    sed -e "s/\[/\{\"timestamp\":${seconds},\"array\":[/g;s/\]/\]\}/g" $WORKINGDIR/darknet/predictions.json >> $VIDEO.json
    rm $WORKINGDIR/darknet/predictions.json
done
echo "]}" >> $VIDEO.json
endTime=$(date +%s)
echo $startTime $endTime
runningTime=$(bc -l <<< "$endTime - $startTime")
sed -i -e "s/N\/A GTFO/$runningTime/g" $VIDEO.json
popd
