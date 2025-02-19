#!/bin/bash

usage()
{
cat << EOF
usage: $0 [options] input_file output_file

OPTIONS:
   -?                               Show this message
   -s start_duration                Remove the first startup_duration seconds of the video
   -e stop_duration                 Cut the video after stop_duration (from the start of the input video)
   -m   	       	            Only show the main screen (ie. remove the webcam)
EOF
}

start_duration=0
stop_duration=0
main_screen_only=n

while getopts 's:e:m' OPTION; do
    case $OPTION in
	s)
	    start_duration=$OPTARG
	    ;;
	e)
	    stop_duration=$OPTARG
	    ;;
	m)
	    main_screen_only=y
	    ;;
	  ?)	usage
	exit 2
	;;
    esac
done

# remove the options from the command line
shift $(($OPTIND - 1))
if [ $# -lt 2 ]; then
    usage
    exit 2
fi

input=$1
output=$2

video_size=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 $input )
height=$(echo $video_size |awk -Fx '{print $2}')
width=$(echo $video_size |awk -Fx '{print $1}')


if [ "$stop_duration" -gt 0 ]; then
    duration=$(echo "$stop_duration - $start_duration"|bc)
    DURATION_OPTION="-t $duration"
fi


echo "height=$height, width=$width"

upper_window=96 # height of the upper part of the firefox window
lower_window=55 # height of the lower part of the firefox window

#out_w is the width of the output rectangle
out_w=$width
if [ "$main_screen_only" = "y" ]; then
    out_w=720
fi

#out_h is the height of the output rectangle
out_h=$(echo "$height - $upper_window - $lower_window"|bc)

#x and y specify the top left corner of the output rectangle
x=0
y=$upper_window


ffmpeg -y -ss $start_duration -i "$input" -filter:v "crop=$out_w:$out_h:$x:$y" $DURATION_OPTION -crf 23 -preset veryslow -pix_fmt yuv420p -strict -2 -acodec aac -vcodec libx264 "$output"
