#!/bin/sh
# Set bundle version of app, and commits it to git
# requires get_build_number.sh,utils.sh,environment.sh shell Script

InfoPlist=EmCuTeeTee/Info.plist

function get_build_number
{
    git rev-list --count --all
}

# Test for local changes function
function test_local_changes
{
    uncommitted_project_files=`git status --porcelain`

    local_changes=$uncommitted_project_files

    if [ "$local_changes" != " " ]; then
        print=0
        echo "You have local changes"
        for w in $local_changes; do

            if [ $print = "0" ]; then
                line=$w
                print=1
            else
                echo $line" "$w
                print=0
            fi
        done

        read -p "Are you sure you want to continue [y/n]? " answer
        if [ "$answer" != "y" ]; then
            exit
        fi
    fi
}

function usage
{
    if [[ -n $1 ]]; then
        echo $1
    fi
    echo "usage: set_bundle_version.sh <version-number>"
    exit -1
}

version_number=$1
build_number=$(get_build_number)

if [[ -z $version_number ]]; then
    usage "set_bundle_version.sh requires a version-number"
fi

build_number=$(($build_number+1))

#edit info.plist file
plutil -replace CFBundleVersion -string $build_number $InfoPlist
plutil -replace CFBundleShortVersionString -string $version_number $InfoPlist

#do we have local changes
test_local_changes

git_comment="Setting Info.plist version to "$version_number" and build to "$build_number
# commit the info.plist after editing
git commit -m "$git_comment" $InfoPlist
