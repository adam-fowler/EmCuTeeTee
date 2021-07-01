#!/bin/sh

set -eux

function resizeImage {
    srcImage=$1
    destImage=$2
    size=$3
    bkgColor=#fff
    magick $srcImage -resize ${size}x${size}\> -size ${size}x${size} xc:$bkgColor +swap -gravity center -composite $destImage
}

resizeImage Images/EmCuTeeTee.png Images/EmCuTeeTee180.png 180
resizeImage Images/EmCuTeeTee.png Images/EmCuTeeTee167.png 167
resizeImage Images/EmCuTeeTee.png Images/EmCuTeeTee152.png 152
resizeImage Images/EmCuTeeTee.png Images/EmCuTeeTee120.png 120
resizeImage Images/EmCuTeeTee.png Images/EmCuTeeTee87.png 87
resizeImage Images/EmCuTeeTee.png Images/EmCuTeeTee80.png 80
resizeImage Images/EmCuTeeTee.png Images/EmCuTeeTee76.png 76
resizeImage Images/EmCuTeeTee.png Images/EmCuTeeTee60.png 60
resizeImage Images/EmCuTeeTee.png Images/EmCuTeeTee58.png 58
resizeImage Images/EmCuTeeTee.png Images/EmCuTeeTee40.png 40
resizeImage Images/EmCuTeeTee.png Images/EmCuTeeTee29.png 29
resizeImage Images/EmCuTeeTee.png Images/EmCuTeeTee20.png 20
