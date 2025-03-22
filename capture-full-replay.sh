#!/bin/bash

scriptdir=$(dirname $(realpath $0))

# progress_bar.sh copied from https://github.com/nachoparker/progress_bar.sh
. $scriptdir/progress_bar.sh


network_name=bbb
# This will capture the replay, played in a controlled web browser,
# using a Docker container running Selenium

usage()
{
cat << EOF
usage: $0 [options] URL

OPTIONS:
   -?                               Show this message
   -s start_duration                Remove the first start_duration seconds of the video
   -e stop_duration                 Cut the video after stop_duration (from the start of the input video)
   -l last_duration                 Remove the last last_duration seconds of the video (relatively to stop_duration)
   -m   	       	            Only show the main screen (ie. remove the webcam)
   -c 				    Don't crop the output video (result video container will be mkv - not mp4)
   -o output_file		    Select the output file
   -S 				    Save all the downloaded videos
   -i input_file		    Download all the videos specified in input_file
   -v                               Enable verbose mode
   -a audio_encoder                 Use specified audio encoder
EOF
}
start_duration=0
stop_duration=0
last_duration=0
main_screen_only=n
crop=y
output_file=""
save=n
input_file=""
verbose=n
docker=n
audio_encoder=aac
docker_option=""

end_video_delay=10
while getopts 'ds:l:e:mco:Si:va:' OPTION; do
    case $OPTION in
	d)
	    docker=y
	    ;;
	s)
	    start_duration=$OPTARG
	    docker_option="$docker_option -s $start_duration"
	    ;;
	e)
	    stop_duration=$OPTARG
	    docker_option="$docker_option -e $stop_duration"
	    ;;
        l)
            last_duration=$OPTARG
            docker_option="$docker_option -l $last_duration"
            ;;
	m)
	    main_screen_only=y
	    docker_option="$docker_option -m"
	    ;;
	c)
	    crop=n
	    docker_option="$docker_option -c"
	    ;;
	o)
	    output_file=$OPTARG
	    ;;
	S)
	    save=y
	    docker_option="$docker_option -s"
	    ;;
	i)
	    input_file=$OPTARG
	    ;;
	v)
	    verbose=y
	    docker_option="$docker_option -v"
	    ;;
        a)
            audio_encoder=$OPTARG
            docker_option="$docker_option -a"
            ;;
	?)
	usage
	exit 2
	;;
    esac
done


# remove the options from the command line
shift $(($OPTIND - 1))

if [ $verbose = y ]; then
    set -x
fi

function capture_in_docker() {
    url=$1
    output_file=$2

    echo "Docker mode"

    output_dir="$PWD"
    if [ -n "$output_file" ]; then
	output_dir=$(realpath $(dirname "$output_file"))
	if ! [ -d "$output_dir" ]; then
	    mkdir -p "$output_dir"
	fi
	output_filename=$(basename "$output_file")
	docker_option="$docker_option -o '/tmp/output/$output_filename'"
    fi

    if ! docker network inspect "$network_name" 2> /dev/null > /dev/null ; then
	echo "Creating network $network_name"
	docker network create "$network_name"
    else
        echo "Network $network_name already exists"
    fi

    docker run --network="$network_name" --rm \
	   -v /var/run/docker.sock:/var/run/docker.sock\
	   -v "$scriptdir":/bbb-downloader \
	   -v "$output_dir":/tmp/output \
	   ftrahay/bbb-downloader \
	   bash -c "/bbb-downloader/capture-full-replay.sh $docker_option $url"
    exit
}

function capture() {
    url=$1
    output_file=$2
    video_id=$3

    if [ -z "$url" ]; then
	exit 1
    fi

    if [ -z "$video_id" ]; then
	exit 1
    fi

    if [ -z "$output_file" ]; then
	if [ "$crop" -eq "y" ]; then
	    output_file=$video_id.mp4
	else
	    output_file=$video_id.mkv
	fi
    fi

    if [ "$docker" = y ]; then
	capture_in_docker "$url" "$output_file"
	exit
    fi

    echo "Downloading $url, and saving it as '$output_file'."
    # Extract duration from associate metadata file
    # seconds=$(python3 bbb.py duration "$url")

    python3 $scriptdir/download_bbb_data.py -V "$url" "$video_id"


    seconds=$(ffprobe -i $video_id/Videos/webcams.webm -show_entries format=duration -v quiet -of csv="p=0")
    seconds=$( echo "($seconds+0.5)/1" | bc 2>/dev/null)
    if [ -z "$seconds" ]; then
        seconds=$(ffprobe -i $video_id/Videos/webcams.mp4 -show_entries format=duration -v quiet -of csv="p=0")
        seconds=$( echo "($seconds+0.5)/1" | bc 2>/dev/null)
        if [ -z "$seconds" ]; then
            seconds=$(python3 $scriptdir/bbb.py duration "$url")
        fi
    fi


    if [ -z "$seconds" ]; then
	echo "Failed to detect the duration of the presentation" >&2
	exit 1
    fi

    container_name=grid #$$

    # Startup Selenium server
	#  -p 5920:25900 : we don't need to connect via VNC

    docker run --network="$network_name" --rm -d --name=$container_name -P -p 24444:24444 \
	   --shm-size=2g -e VNC_PASSWORD=hola \
	   -e VIDEO=true -e AUDIO=true \
	   -e SCREEN_WIDTH=1680 -e SCREEN_HEIGHT=1031 \
	   -e VIDEO_FILE_EXTENSION="mkv" \
	   -e FFMPEG_DRAW_MOUSE=0 \
	   -e FFMPEG_FRAME_RATE=60 \
           -e FFMPEG_CODEC_ARGS="-c:v copy -c:a copy" \
           -e FFMPEG_CODEC_VA_ARGS="-c:v libx264 -crf 0 -qp 0 -c:a copy -preset ultrafast -g 180" \
	   elgalu/selenium

    if [ $? -ne 0 ]; then
	echo "docker run failed!" >&2
	exit 1
    fi

    bound_port=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "24444/tcp") 0).HostPort}}' $container_name)
    container_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container_name)

    docker exec $container_name wait_all_done 30s

    if [ -d /opt/bbb-downloader/node_modules ]; then
	export NODE_PATH="$NODE_PATH:/opt/bbb-downloader/node_modules"
    fi

    video_start_time=$(date +%s)

    # Run selenium to start video
    node $scriptdir/selenium-play-bbb-recording.js "$url" $container_ip:$bound_port

    playback_start_time=$(date +%s)

    # Now wait for the duration of the recording, for the capture to happen

    # Instead of waiting without any feedback to the user with a simple
    # "sleep", we use the progress bar script.

    capture_delay=$(expr $seconds + $end_video_delay)

    echo
    echo "Please wait for $capture_delay seconds, while we capture the playback..."
    echo

    set +x # disable verbosity to avoid flooding the logs
    progress_bar $capture_delay

    if [ $verbose = y ]; then
	set -x
    fi

    # Save the captured video
    docker exec $container_name stop-video

    output_dir=$(mktemp -d)

    docker cp $container_name:/videos/. $output_dir/
    docker stop $container_name
    docker kill $container_name

    captured_video=$(ls -1 $output_dir/*.mkv)

    if [ $start_duration -eq 0 ]; then
        start_duration=$(expr $playback_start_time - $video_start_time - 2)
    fi

    if [ $stop_duration -eq 0 ]; then
        stop_duration=$(expr $playback_start_time - $video_start_time - 2 + $seconds + $end_video_delay - $last_duration)
    fi

    echo
    echo "seconds=$seconds"
    echo "start_duration=$start_duration"
    echo "stop_duration=$stop_duration"
    echo "capture_delay=$capture_delay"

    if [ "$crop" = "y" ]; then
	if [ "$main_screen_only" = y ]; then
	    OPTIONS=-m
	else
	    OPTIONS=""
	fi
	bash $scriptdir/crop_video.sh -s "$start_duration" -e "$stop_duration" -a "$audio_encoder" $OPTIONS $captured_video $output_file
    else
	mv $captured_video $output_file
    fi
    rm -fr $output_dir

    if [ "$save" = n ]; then
	rm -r $video_id
    fi

    echo
    echo "DONE. Your video is ready in $output_file"

}

if [ -z "$input_file" ]; then

    if [ $# -lt 1 ]; then
	usage
	exit 2
    fi

    url=$1
    if [ -n "$url" ]; then
	video_id=$(python3 $scriptdir/bbb.py id "$url")
	capture "$url" "$output_file" "$video_id" 2>&1 |tee "capture_${video_id}.log"
    fi
else
    if ! [ -r $input_file ]; then
	echo "Error: cannot open  file $input_file" >&2
	exit 2
    fi

    while read url output_file ; do
	if [ -n "$url" ]; then
	    output_file=$(echo $output_file| tr -d '\r')
	    video_id=$(python3 $scriptdir/bbb.py id "$url")
	    capture "$url" "$output_file" "$video_id" 2>&1 |tee "capture_${video_id}.log"
	fi
    done < $input_file
    exit 1
fi

