#!/bin/bash
# set -x

RESET="\033[0m"
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
WHITE="\033[37m"
msg() { echo -e "$*"; }
msg_red() { msg "$RED$*$RESET"; }
msg_blue() { msg "$BLUE$*$RESET"; }
msg_cyan() { msg "$CYAN$*$RESET"; }
msg_green() { msg "$GREEN$*$RESET"; }
msg_yellow() { msg "$YELLOW$*$RESET"; }
msg_magenta() { msg "$MAGENTA$*$RESET"; }
msg_white() { msg "$WHITE$*$RESET"; }

WORKING_DIR=$PWD
TMP_DIR=$WORKING_DIR/tmp
APK_PROVIDER="https://www.apkmirror.com"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
RV_CLI_API="https://api.github.com/repos/revanced/revanced-cli/releases/latest"
RV_PATCH_API="https://api.github.com/repos/revanced/revanced-patches/releases/latest"

download_silent() {
	curl -s -L -A "$USER_AGENT" "$1" || { msg_red "Download faild ..." && exit 1; }
}

download_progress() {
	if [ -f "$2" ] ; then
		msg_green " ${2##*/} has already downloaded"
	else
		msg_cyan "==> Downloading $1"
		curl --progress-bar -L -A "$USER_AGENT" "$1" -o "$2" || { msg_red "Download faild ..." && exit 1; }
		msg_green "🍺 $2"
	fi
}

download_rv_cli_patches() {
	msg_cyan "==> Fetching revanced-cli,revanced-patches ..."
	RV_CLI_DOWNLOAD_URL=$(download_silent "$RV_CLI_API" | sed -nE "s|.*download_url\": \"(.*jar)\".*|\1|p")
	RV_PATCH_DOWNLOAD_URL=$(download_silent "$RV_PATCH_API" | sed -nE "s|.*download_url\": \"(.*rvp)\".*|\1|p")
	RV_CLI_OUTPUT=${RV_CLI_DOWNLOAD_URL##*/}
	RV_PATCH_OUTPUT=${RV_PATCH_DOWNLOAD_URL##*/}
	RV_PATCH_VERSION=$(echo "$RV_PATCH_OUTPUT" | sed -nE "s|patches-(.*).rvp|\1|p")
	
	download_progress "$RV_CLI_DOWNLOAD_URL" "$TMP_DIR/$RV_CLI_OUTPUT"
	download_progress "$RV_PATCH_DOWNLOAD_URL" "$TMP_DIR/$RV_PATCH_OUTPUT"
}

download_apk() {
	msg_cyan "==> Fetching $1 ..."
	[ -z "$VERSION" ] && msg_red "No such version of [ $APP ][ v$VERSION ]" && exit 1
	DOWNLOAD_HREF=$(download_silent "$1" | tr -d '\n' | sed 's|svg class|\n|g' | sed -nE "s|.*$ARCH.*nodpi.*accent_color\" href=\"([^\"]*)\".*|\1|p")
	DOWNLOAD_HREF=$(download_silent "${APK_PROVIDER}$DOWNLOAD_HREF" | sed -nE 's|.*href="(.*\/download\/[^"]*)".*|\1|p' | sed 's|&amp;|\&|g')
	DOWNLOAD_HREF=$(download_silent "${APK_PROVIDER}$DOWNLOAD_HREF" | sed -nE 's|.*href="(.*download.php[^"]*)".*|\1|p' | sed 's|&amp;|\&|g')
	DOWNLOAD_URL="${APK_PROVIDER}$DOWNLOAD_HREF"

	download_progress "$DOWNLOAD_URL" "$2"
}

select_app() {
	PS3="Select an app to build: "
	select APP in youtube youtube-music tiktok
	do
	    case $APP in
	        youtube|youtube-music|tiktok)
				break;;
	        *)
				msg_red "Ooops ..."
				;;
	    esac
	done
}

select_verion() {
	case $APP in
		youtube)
			PACKAGE_NAME="com.google.android.youtube"
			COMPANY=google-inc
			PRODUCT=youtube
			ARCH="universal"
			;;
		youtube-music)
			PACKAGE_NAME="com.google.android.apps.youtube.music"
			COMPANY=google-inc
			PRODUCT=youtube-music
			ARCH="arm64-v8a"
			;;
		tiktok)
			PACKAGE_NAME="com.zhiliaoapp.musically"
			COMPANY=tiktok-pte-ltd
			PRODUCT=tik-tok-including-musical-ly
			ARCH="arm64-v8a"
			;;
		*)
			msg_red "Please select 'youtube', 'youtube-music' or 'tiktok'"
			exit 1
			;;
	esac

	APK_INFO_URL="$APK_PROVIDER/apk/$COMPANY/$PRODUCT"

	VERSION=$(echo "$RV_PATCH_LIST" | sed -nE "s|.*${PACKAGE_NAME}##Compatible versions:[0-9\.\#]*###([0-9\.]*)##.*|\1|p")
	if [ -z "$VERSION" ]; then
		VERSION=$(download_silent "$APK_INFO_URL" | grep "About" | sed -nE "s|.*About .* ([0-9\.]*).*|\1|p")
	fi

	APK_URL="$APK_INFO_URL/$PRODUCT-$VERSION-release/"
}

check_include_exclude() {
	case $APP in
		youtube)
			include_patch_list=(
				"Change header"
				)
			exclude_patch_list=()
			;;
		youtube-music)
			include_patch_list=(
				"Permanent repeat"
				"Hide category bar"
				)
			exclude_patch_list=()
			;;
		tiktok)
			include_patch_list=(
				"SIM spoof"
				)
			exclude_patch_list=()
			;;
		*)
			msg_red "Please select 'youtube', 'youtube-music' or 'tiktok'"
			exit 1
			;;
	esac
	msg_cyan "==> Checking Patches for including and excluding ..."
	if [ -n "$include_patch_list" ]; then
		msg_magenta "Including Patches ..."
		for i in "${include_patch_list[@]}"; do
			if printf "%s" "$RV_PATCH_LIST" | grep -iq "$(printf '%s' "$i")"; then
				include_patches+=" --enable \"$i\""
				res="${GREEN} ✔"
			else
				res="${RED} ✖"
				check=1
			fi
			msg "$res" "$i" "${RESET}"
		done
	else
		msg_yellow "Nothing to Include"
	fi

	if [ -n "$exclude_patch_list" ]; then
		msg_magenta "Excluding Patches ..."
		
		for i in "${exclude_patch_list[@]}"; do
			if printf "%s" "$RV_PATCH_LIST" | grep -iq "$(printf '%s' "$i")"; then
				include_patches+=" --disable \"$i\""
				res="${GREEN} ✔"
			else
				res="${RED} ✖"
				check=1
			fi
			msg "$res" "$i" "${RESET}"
		done
	else
		msg_yellow "Nothing to Exclude"
	fi

	if [ -n "$check" ]; then
		msg_red "==> Some of the patches are not in the patch list, check all failed patches by using:"
		msg_white "java -jar '$TMP_DIR/$RV_CLI_OUTPUT' list-patches '$TMP_DIR/$RV_PATCH_OUTPUT' --with-packages"
		exit 1
	else
		msg_green " All listed Patches Included and Excluded"
	fi
}

# main
main() {

	[ -d "$TMP_DIR" ] || mkdir -p "$TMP_DIR"

	download_rv_cli_patches

	cmd_patch_list="java -jar $TMP_DIR/$RV_CLI_OUTPUT list-patches \
		$TMP_DIR/$RV_PATCH_OUTPUT \
		--with-descriptions=false \
		--with-packages \
		--with-versions"

	RV_PATCH_LIST=$(eval "$cmd_patch_list" | tr '\n\t' '#')

	[ -z "$1" ] && select_app || APP=$1
	[ -z "$2" ] && select_verion || VERSION=$2

	ORIGIN_APK="$TMP_DIR/$APP-$VERSION.apk"
	RV_APK="$WORKING_DIR/$APP-$VERSION-revanced-patches-$RV_PATCH_VERSION.apk"

	download_apk "$APK_URL" "$ORIGIN_APK"

	check_include_exclude

	msg_cyan "==> Patching $ORIGIN_APK ..."

	cmd_patch="java -jar $TMP_DIR/$RV_CLI_OUTPUT patch \
		--patches $TMP_DIR/$RV_PATCH_OUTPUT \
		--keystore revanced.keystore \
		--temporary-files-path $TMP_DIR/revanced-tmp \
		$include_patches \
		$exclude_patches \
		--options \"header=premium*header\" \
		--out $RV_APK \
		$ORIGIN_APK"
	msg_white "$cmd_patch" | tr -d '\t'
	eval "$cmd_patch"
}

main "$@"