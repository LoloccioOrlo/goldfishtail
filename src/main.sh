#!/bin/bash

# CONFIG
MTGGOLDFISH=${GOLDFISHTAIL_MTGGOLDFISH:-"https://www.mtggoldfish.com/"}
MTGGOLDFISHDECK="${MTGGOLDFISH}deck/"
MTGGOLDFISHDOWNLOAD="${MTGGOLDFISHDECK}download/"
DECKLISTMAKER=${GOLDFISHTAIL_MAKER:-"https://www.decklist.org/"}
CONFIGPATH=${GOLDFISHTAIL_CONFIG:-"$HOME/.goldfishtail"}

# DECKINFO
FIRSTNAME=
LASTNAME=
DCINUMBER=
EVENT=
EVENTDATE=
EVENTLOCATION=
DECKSHEET=
DECKNAME=
DECKDESIGNER=
DECKMAIN=
DECKSIDE=

# arg: configpath
read_config () {
	if [ ! -f $CONFIGPATH ]; then
		echo "" > $CONFIGPATH
	fi
	. $CONFIGPATH
}

# arg: NONE
intaractive_init_config () {
	read_config
	local firstname
	local lastname
	local dcinumber
	local decksheet
	DECKSHEET=${DECKSHEET:-"wotc"}
	read -p "Your First Name (Default: $FIRSTNAME): " -r firstname
	firstname=${firstname:-$FIRSTNAME}
	read -p "Your Last Name (Default: $LASTNAME): " -r lastname
	lastname=${lastname:-$LASTNAME}
	read -p "Your DCI NUMBER (Default: $DCINUMBER): " -r dcinumber
	dcinumber=${dcinumber:-$DCINUMBER}
	read -p "Decklist Type (wotc/scg) (Default: $DECKSHEET): " -r decksheet
	decksheet=${decksheet:-$DECKSHEET}
	while [ ! "$decksheet" = "wotc" ] && [ ! "$decksheet" = "scg" ]; do
		read -p "Type 'wotc' or 'scg': " -r decksheet
	done
	cat <<-_EOF > $CONFIGPATH
		FIRSTNAME=$firstname
		LASTNAME=$lastname
		DCINUMBER=$dcinumber
		DECKSHEET=$decksheet
	_EOF
	read_config
	if [ $? = 0 ]; then
		echo "SUCCEED." >&2
	else
		echo "[Error] Cannot Initialize Config." >&2
	fi
}

# arg: deckid
fetch_deck_info () {
	local id url info page
	id=$1
	url="${MTGGOLDFISHDECK}${id}"

	page=$(curl -s "$url")
	if [ $? != "0" ]; then
		echo "[Error] Cannot Access ${url}" >&2
		exit 1
	fi

	info=$(echo "$page" | sed -n "/<h1 class='deck-view-title'>/,/<\/h1>/p")
	DECKNAME=$(echo "$info" | sed -n "2,2p")
	DECKDESIGNER=$(echo "$info"| sed -n "s/<span\ class='deck-view-author'>by //gp" | sed "s/<\/span>//")
	if [ -z "$DECKNAME" ] || [ -z "$DECKDESIGNER" ]; then
		echo "[Error] Cannot Get Deck-Name and/or Deck-Designer from ${url}" >&2
	fi
}

# arg: deckid
fetch_deck_list () {
	local id url
	id=$1
	url="${MTGGOLDFISHDOWNLOAD}${id}"

	page=$(curl -s "$url" | sed "s/\r$//g")
	if [ $? != "0" ]; then
		echo "[Error] Cannot Access ${url}" >&2
		exit 1
	fi

	DECKMAIN=$(echo "$page" | sed -n "0,/^$/p" | sed "s/^$//g")
	DECKSIDE=$(echo "$page" | sed -n "/^$/,//p" | sed "s/^$//g")
	if [ -z "$DECKMAIN" ]; then
		echo "[Error] Cannot Get Decklist from ${url}" >&2
		exit 1
	fi
}

# arg: deckid
make_register_sheet_url () {
	read_config
	local url main side
	url="$DECKLISTMAKER"
	url="${url}?firstname=${FIRSTNAME// /%20}"
	url="${url}&lastname=${LASTNAME// /%20}"
	url="${url}&dcinumber=${DCINUMBER}"
	url="${url}&event=${EVENT// /%20}"
	url="${url}&eventdate=${EVENTDATE}"
	url="${url}&eventlocation=${EVENTLOCATION// /%20}"
	url="${url}&decksheet=${DECKSHEET}"
	url="${url}&deckname=${DECKNAME// /%20}"
	url="${url}&deckdesigner=${DECKDESIGNER// /%20}"
	main=$(echo "$DECKMAIN" | sed "s/$/%0A/g" | tr -d '\n')
	url="${url}&deckmain=${main// /%20}"
	side=$(echo "$DECKSIDE" | sed "s/$/%0A/g" | tr -d '\n')
	url="${url}&deckside=${side// /%20}"

	echo "$url"
}

# arg: NONE
usage_exit () {
	cat <<- _EOF >&2
		Usage: goldfishtail [init] decimal-deckid
		    init:
		        init your name and dci.
		    decimal-deckid:
		        deck-id of your deck.
		        for example,
		        'https://www.mtggoldfish.com/deck/1901221' has id '1901221'
	_EOF
	exit 1
}

########
# MAIN #
########

case "$1" in
	init)
		intaractive_init_config
		exit 0
		;;
	*)
		ID=$1
		;;
esac

if [[ ! "$ID" =~ ^[1-9][0-9]*$ ]]; then
	usage_exit
fi

fetch_deck_info "$ID"
fetch_deck_list "$ID"
make_register_sheet_url
