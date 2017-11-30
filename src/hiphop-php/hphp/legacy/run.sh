#!/bin/sh
#$1: output directory
#$2: program name
#$3: extra flags, for exmaple, RELEASE=1
   #echo make -j $3 PROJECT_NAME=$2 TIME_LINK=1 -C $1
cp $HPHP_HOME/hphp/legacy/CMakeLists.base.txt $1/CMakeLists.txt
cd $1

# If hphc was called from a makefile, don't propogate
# environment nonsense to the child, because this breaks tests
# I wish there was an exhaustive list of these somewhere
unset MAKEFLAGS
unset MAKEOVERRIDES
unset MFLAGS
unset MAKELEVEL

cmake -D PROGRAM_NAME:string=$2 . || exit $?

if [ -n "$HPHP_VERBOSE" ]; then
  make $MAKEOPTS > /dev/tty || exit $?
else
  make $MAKEOPTS || exit $?
fi
