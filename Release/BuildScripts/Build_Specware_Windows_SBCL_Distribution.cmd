@echo off

set "FLAGS=%1"

if "%SPECWARE4%"=="" (
  set "SPECWARE4=C:\Specware4"
)

if "%DISTRIBUTION%"=="" (
  set "DISTRIBUTION=C:\Distribution"
)

if not exist "%SPECWARE4%" (
  echo Cannot find Specware4 directory: %SPECWARE4%
  exit -1
)

if not exist "%DISTRIBUTION%" (
  echo Cannot find distribution directory: %DISTRIBUTION%
  exit -1
)

set VERBOSE=t

set "LISP_EXECUTABLE=sbcl"
set "LISP_HEAP_IMAGE=NONE

cd "%SPECWARE4%\Release\BuildScripts\"

start "Build Specware Distribution" sbcl --load "BuildSpecwareDistribution.lisp" --eval "(progn (cl-user::build-specware-release %VERBOSE%) (sleep 9) (exit 0))"







