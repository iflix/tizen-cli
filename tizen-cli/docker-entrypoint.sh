#! /bin/bash

set -e

# Print all messages to STDERR, reserve STDOUT for data output
exec 3>&1
exec 1>&2

DOCKER_IMAGE=jansuchy/tizen-cli

print_help_exit() {
    [ -n "$1" ] && MESSAGE=$'\nERROR: '"$1"$'\n'
    cat <<EOF
$MESSAGE
Usage:

  docker run -i --rm \\
    -v </abs/path/author_cert_pkcs12>:/run/secrets/author_cert_pkcs12 \\
    -v </abs/path/author_cert_password>:/run/secrets/author_cert_password \\
    $DOCKER_IMAGE [package] [install <device-ip-address>] | [[run | uninstall] <device-ip-address> <package-id>] | shell

Possible command combinations:

  package - Accepts app tar archive on STDIN, sends .wgt archive to STDOUT
  install - Accepts .wgt on STDIN
  package install - Accepts app tar archive on STDIN
  run - Runs an application identified by package id. Package id can be found in the config.xml
    manifest tag:  <tizen:application id="some-pkg-id" ...>. If the application is already running
    in the background, this commands puts the it in the foreground and resumes it.
  uninstall - Uninstalls an application identified by package id.
  exec - executes a shell command in the container

Examples:

Package your app and install it to a tizen device:
  tar -c app | docker run -i --rm -v \$PWD/secrets:/run/secrets \\
    $DOCKER_IMAGE package install 192.168.88.242

Note: In this example we mount a single dir that contains both certificate and password files.

Package your app to a .wgt file:
  tar -c app | docker run -i --rm -v \$PWD/secrets:/run/secrets \\
    $DOCKER_IMAGE package > app.wgt

Install a .wgt package to a tizen device:
  docker run -i --rm $DOCKER_IMAGE install 192.168.88.242 < app.wgt

Run application O0heDdWYtm.iflix on device with IP address 192.168.88.242:
  docker run -i --rm $DOCKER_IMAGE run 192.168.88.242 O0heDdWYtm.iflix

Uninstall application O0heDdWYtm.iflix from device with IP address 192.168.88.242:
  docker run -i --rm $DOCKER_IMAGE uninstall 192.168.88.242 O0heDdWYtm.iflix

Display Tizen CLI version in the $DOCKER_IMAGE container:
  docker run -i --rm $DOCKER_IMAGE exec tizen version

Run interactive bash session in the $DOCKER_IMAGE container:
  docker run -it --rm $DOCKER_IMAGE exec bash

EOF
    exit 1
}

create_security_profile() {
    [ -r "$AUTHOR_CERT_PKCS12_FILE" ] || print_help_exit "You must provide author certificate in PKCS12 format to build the package"
    [ -r "$AUTHOR_CERT_PASSWORD_FILE" ] || print_help_exit "You must provide author certificate password (even empty one)"
    tizen security-profiles add -n $SECURITY_PROFILE -a $AUTHOR_CERT_PKCS12_FILE -p $(cat $AUTHOR_CERT_PASSWORD_FILE)
}

BUILD_DIR=/tmp/build
PKG_DIR=/tmp/pkg
AUTHOR_CERT_PKCS12_FILE=/run/secrets/author_cert_pkcs12
AUTHOR_CERT_PASSWORD_FILE=/run/secrets/author_cert_password
# $TIZEN_STUDIO installation path is declared in Dockerfile
PATH=$TIZEN_STUDIO/tools:$TIZEN_STUDIO/tools/ide/bin:$PATH
SECURITY_PROFILE=secprofile
PKG=

CMD="$1"
shift || print_help_exit "Missing command"

if [ "$CMD" == "package" ]; then
    # Build package and sign it
    mkdir -p $BUILD_DIR
    tar -xC $BUILD_DIR || print_help_exit "You must provide a tar archive with the app on standard input"
    BUILD_DIR=$(dirname $(find $BUILD_DIR -name config.xml -print | head -1)) || print_help_exit "Cannot find widget configuration file config.xml in application dir"
    create_security_profile
    mkdir $PKG_DIR
    tizen package -t wgt -s $SECURITY_PROFILE -o $PKG_DIR -- $BUILD_DIR
    PKG=$(echo $PKG_DIR/*)

    # Next command?
    CMD="$1"
    if [ "$CMD" == "install" ]; then
	# We allow to continue with install right away...
	shift
    else
	# ...otherwise send the .wgt package to STDOUT and exit
	exec 1>&3
	cat "$PKG"
	exit $?
    fi
fi

if [ "$CMD" == "install" ] || [ "$CMD" == "run" ] || [ "$CMD" == "uninstall" ]; then
    DEVICE_IP="$1"
    shift || print_help_exit "Missing device-ip-address command line parameter"
fi

if [ "$CMD" == "install" ]; then
    if [ -z "$PKG" ]; then
	# We haven't built anything this time: Expect .wgt package on STDIN instead.
	mkdir $PKG_DIR
	PKG="$PKG_DIR/widget.wgt"
        cat >"$PKG"
    fi
    [ -s "$PKG" ] || print_help_exit "You must provide a .wgt package on standard input or build one with the 'package' command"
    # Install the package on remote Tizen device
    sdb connect "$DEVICE_IP":26101
    tizen install --name $(basename $PKG) -- $PKG_DIR
    exit $?
fi

if [ "$CMD" == "run" ] || [ "$CMD" == "uninstall" ]; then
    PACKAGE_ID="$1"
    shift || print_help_exit "Missing package-id command line parameter"
    sdb connect "$DEVICE_IP":26101
    tizen $CMD --pkgid "$PACKAGE_ID"
    exit $?
fi

if [ "$CMD" == "exec" ]; then
    [ -n "$@" ] || print_help_exit "Missing command to execute"
    exec $@
fi

print_help_exit "Invalid command line"
