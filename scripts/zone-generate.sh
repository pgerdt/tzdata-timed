#!/bin/bash -e

# set -o xtrace

# This script has to be executed in the build directory

zic=bin/zic
yearistype=bin/yearistype
signature=bin/signature
leapseconds=leapseconds

output=zones
signatures=signatures
md5sum=md5sum
links=zone.link

icu_input=/usr/share/icu/icuzones
icu_output=zones-icu
icu_zic=/usr/bin/zic-icu
icu_tz2icu=/usr/bin/tz2icu
icu_genrb=/usr/bin/genrb

test -x $zic
test -x $yearistype
test -x $signature
test -r $leapseconds
test -r $icu_input
test -x $icu_zic
test -x $icu_tz2icu
test -x $icu_genrb
rm -rf $output $icu_output $signatures $md5sum && mkdir -p $output $icu_output

input="africa antarctica asia australasia europe northamerica southamerica"
input="$input iso8601"
input="$input etcetera factory systemv backward"
input="$input solar87 solar88 solar89"

for i in $input ; do
  echo "Processing '$i'"
  $zic -d $output -L /dev/null -y $yearistype $i 2> stderr
  $zic -d $output/posix -L /dev/null -y $yearistype $i 2>> stderr
  $zic -d $output/right -L $leapseconds -y $yearistype $i 2>> stderr
  cat stderr | grep -v "time zone abbreviation differs from POSIX standard" >&2 || true
done
$zic -d $output -p America/New_York

echo "Processing all zones again (for libicu)"
$icu_zic -y $yearistype -d $icu_output -L /dev/null $input $icu_input 2> stderr
$icu_zic -d $icu_output -p America/New_York
cat stderr | grep -v "time zone abbreviation differs from POSIX standard" >&2 || true
echo -n "Olson data version:" && cat tzdata_version
$icu_tz2icu $icu_output ./zone.tab $(cat tzdata_version)
echo "Compiling zoneinfo64.txt file to .res binary"
$icu_genrb -k -q -i . -d . zoneinfo64.txt

zones=$(
  for f in $(cd $output ; echo *) ; do
    if [ "$f" = "posix" ] || [ "$f" = "right" ] ; then
      true # skip posix/* right/*
    elif test -d $output/$f ; then
      ( cd $output && find $f -type f )
    elif test -f $output/$f ; then
      echo $f
    fi
  done
)

( cd $output && md5sum $zones ) > $md5sum
$signature `pwd`/$output $zones > $signatures
cat $input | pcregrep '^\s*Link\s+' > $links

