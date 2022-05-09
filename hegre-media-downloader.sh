#!/bin/bash

# Initialize all the variables.
# This ensures we are not contaminated by variables from the environment.
task=0
url_base=false
type=both
thumbnail=false
latest=1
date=false
model=false
quality=false
custom=false
format=0
verbose=0
month=false
interactive=true
base_urls_list="base_urls_list.txt"
raw_urls_list="raw_urls_list.txt"
error="$(tput setaf 1)ERROR!$(tput sgr 0)"
success="$(tput setaf 2)SUCCESS!$(tput sgr 0)"
warning="$(tput setaf 11)WARNING!$(tput sgr 0)"

#BEGIN FUNCTION SECTION

help() {
  echo "Script for downloading from Hegre"
  echo
  echo "Syntax: "
  echo "${0##*/} --download --create-links --url [XXX] --thumbnail --type [film/gallery/all] --latest n --date YYYY/MM --model foo --custom-files --verbose --interactive [yes/no] "
  echo
  echo " Main Options:"
  echo " --download		Run the download [Default - no download]"
  echo " --create-links		Create or update links [Default - no link generation]"
  echo " --url			Download specific search results or pages of your choice. Supplying a URL will skip any URL generation. [Default - None]"
  echo
  echo " Link Generation options:"
  echo " --type			Choose between film, gallery or both [Default - both]"
  echo " --latest			How many files to download [Default - all files matched by the other options]"
  echo " --date			Select a date for the media [Default - current year and month]"
  echo ' --model			Download only files from the named model. Please use the url name including any letter: i.e "natalia-a" or "ani" or "dasha-t" [Default - download all models]'
  echo
  echo " Extras:"
  echo " --thumbnail		Optionally download thumbnails for each media [Default - no thumbnails]"
  echo " --custom-files		Change where to store links [Default - base_urls_list.txt and raw_urls_list.txt]"
  echo " --verbose		Show Extra status messages"
  echo " --interactive [yes/no]	Interactive Option Selection [default yes]"
  echo "You must pick either --download or --create-links (or both) for this script to do anything. All other options are not required"
}

#Exit with messages

die() {
  printf '%s\n' "$1" >&2
  exit 1
}

#Check requirements

require() {
  for what in "$@"; do
    if ! (which "$what" >&/dev/null); then
      die "$error $what is required to run this script, please install it"
      exit 1
    fi
  done
}

#Customise storage of links

custom_files() {
  if [[ $interactive == false ]]; then
    die "$error custom files option can only be used interactivly"
  else
    base_urls_list=$(whiptail --inputbox "Enter the name of the file where the raw URLs are stored:" 10 60 "base_urls_list.txt" 3>&1 1>&2 2>&3)
    raw_urls_list=$(whiptail --inputbox "Enter the name of the file where the list of direct media to be downloaded will be stored:" 10 60 "raw_urls_list.txt" 3>&1 1>&2 2>&3)
  fi
}

# Creation of raw URLs to download

create_raw_urls() {
  if ((verbose == 1)); then
    printf "$warning Creating Raw URLS.  This can take a while depending on the number of URLs to process \n"
  fi
  grep -v '^ *#' <"$base_urls_list" | while IFS= read -r line; do
    curl -s "$line" | grep -v "p.hegre.com" | grep -v "cdn2.hegre.com" | grep -E $format | grep -o "http[^ '\"]*" | sed 's/\?.*//' | awk 'NR>1' | head -n 1
  done >"$raw_urls_list"
}

#Create links that contain one or more media files for the download

create_links() {
  if ((verbose == 1)); then
    printf "Creating Links \n"
    printf "$warning This can take a while depending on the number of URLs to process \n"
  fi
  curl -s $url_base |grep -E 'a href="/photos/|a href="/films/' | cut -d "<" --output-delimiter ">" -f 2 | sed 's,a href=",https://www.hegre.com,' | sed 's/" .*/ /' | grep "hegre" >> "$base_urls_list"
  if ((verbose == 1)); then
    printf "$success Creation of base URLs for %s\n" "$url_base"
  fi
}

#Generate links from supplied options

generate_links() {
if [[ $url_base == false ]]; then
  if [[ $date == false ]] && [[ $model == false ]]; then
    if ((verbose == 1)); then
      printf "$success Downloading content from %s. Processing...... \n" "$(date "+%B %Y")"
    fi
    url_base="https://www.hegre.com/search?month=$(date +M)&year=$(date +Y)"
    create_links
  elif [[ $date == false ]] && [[ $model != false ]]; then
    if ((verbose == 1)); then
      printf "$success Downloading content from %s. Processing...... \n" "$model"
    fi
    url_base="https://www.hegre.com/models/$model"
    create_links
  elif [[ $date != false ]] && [[ $model != false ]]; then
    die "$error Sorry using dates and models together is not supported!"
  elif [[ $date != false ]] && [[ $model == false ]]; then
    if (( verbose == 1 )); then
      printf "$success Downloading content from %s. Processing...... \n" "$date"
    fi
    year=${date:0:4}
    month=${date:6:7}
    if (( month > 1 )); then
      url_base="https://www.hegre.com/search?month=$month&year=$year"
      create_links
    elif (( year >2001 && year < $(date +%Y) )) ; then
      for month in {1..12}; do
        url_base="https://www.hegre.com/search?month=$month&year=$year"
        create_links
      done
    else
     die "$error There is something wrong with your date. Please use the number form YYYY or YYYY/MM only."
    fi
  else
    die "$error Sorry I don't understand what you want to download. I got the options of URL = %s Model = %s Date =  %s and Type = %s" "url_base" "$model" "$date" "$type"
  fi
  create_raw_urls
else
  create_links
  create_raw_urls
fi
}

#Run download of existing links

download() {
  if [[ $interactive == false ]]; then
    read -p -r "Enter Hegre Username: " username
    printf "\n"
    read -s -p -r "Enter Hegre Password: " password
    printf "$success This would be a download"
#    screen -dmS download_hegre_content bash -c "wget -i $raw_urls_list -q --show-progress --user $username --password $password"
    if ((verbose == 1)); then
      printf "\n$success Downloads Started in the background \n"
      printf "$success Your can attach and view the downloads with \"screen -r download_hegre_content\" \n "
    fi
  else
    whiptail --title "Hegre Media Downloader" --msgbox "After this message you will have to enter your login for Hegre." 15 60
    username=$(whiptail --inputbox "Enter your username:" 10 60 3>&1 1>&2 2>&3)
    password=$(whiptail --passwordbox "Enter your password:" 10 60 3>&1 1>&2 2>&3)
    whiptail --title "Hegre Media Downloader" --msgbox "— After clicking ok, a download screen will appear. You can run 'CTRL + A + D' to keep it in the background.\n— To see the list of retrieved URLs, run the command 'cat $raw_urls_list'." 10 60
    printf "$success This would be a download"
#    screen -dmS download_hegre_content bash -c "wget -i $raw_urls_list -q --show-progress --user $username --password $password"
#    screen -r download_hegre_content
  fi
}

#END FUNCTION CREATION

#Basic checks

if [[ $interactive ==  false ]]; then
  require curl pv screen
else
  require curl pv screen whiptail
fi

case "$(curl -s --max-time 2 -I https://www.hegre.com/ | sed 's/^[^ ]*  *\([0-9]\).*/\1/; 1q')" in
[23]) ;;
5) die "$error The web proxy does not let us through" ;;
*) die "$error The network is down or very slow" ;;
esac

#end basic checks

#Process the arguments

while :; do
  case "${1,,}" in
  -h | --help)
    help # Display a usage synopsis.
    exit
    ;;
  -d | --download)
    task=$((task + 1))
    ;;
  -c | --create-links)
    task=$((task + 2))
    ;;
  -u | --url)
    if [[ "$2" ]]; then
      url_base=$2
      shift
    else
      die "$error: \"url\" requires a non-empty option argument."
    fi
    ;;
  -t | --type)
    if [[ "$2" ]]; then
      type=$2
      shift
    else
      die "$error: \"type\" requires a non-empty option argument."
    fi
    ;;
  -n | --thumbnail | --thumbnails)
    thumbnail=true
    ;;
  -l | --latest)
    if [[ "$2" ]]; then
      latest=$2
      shift
    else
      die "$error: \"latest\" requires a non-empty option argument."
    fi
    ;;
  -y | --date)
    if [[ "$2" ]]; then
      date=$2
      shift
    else
      die "$error: \"date\" requires a non-empty option argument."
    fi
    ;;
  -m | --model)
    if [[ "$2" ]]; then
      model=$2
      shift
    else
      die "$error: \"model\" requires a non-empty option argument."
    fi
    ;;
  --quality)
    if [[ "$2" ]]; then
      quality=$2
      shift
    else
      die "$error: \"quality\" requires a non-empty option argument."
    fi
    ;;
  --custom-files)
    custom=true
    ;;
  --interactive)
    if [[ $2 == "no" ]]; then
      interactive=false
      shift
    fi
    ;;
  --verbose)
    verbose=1
    ;;
  -?*)
    die "$error: Unknown option: $1" >&2
    ;;
  *) # Default case: No more options, so break out of the loop.
    break ;;
  esac

  shift
done
#end options

#Main program

if [[ $interactive == false ]]; then
  printf "Thank you for downloading the program. \nIf you find this program useful, don't forget to give a star! \n— https://github.com/baptiste313/hegre-media-downloader/"
fi

if ((task == 0)); then
  die "$error: You need to specify one of the core options (--download or --create-links)"
fi

if [[ $thumbnail == true ]]; then
  if [[ $type == "films" ]]; then
    format=".mp4|.jpg"
  elif [[ $type == "galleries" ]]; then
    format=".zip|.jpg"
  elif [[ $type == "both" ]]; then
    format=".mp4|.zip|.jpg"
  else
    die "$error: \"type\" is unknown."
  fi
else
  if [[ $type == "films" ]]; then
    format=".mp4"
  elif [[ $type == "gallery" ]]; then
    format=".zip"
  elif [[ $type == "both" ]]; then
    format=".mp4|.zip"
  else
    die "$error: \"type\" is unknown."
  fi
fi

if [[ $custom == "true" ]]; then
  custom_files
else
  if ((verbose == 1)); then
    printf "$success Using default files for link storage \n"
  fi
fi

if ((task == 1)); then #Downloads Only
  if [[ -s $raw_urls_list ]]; then
    if ((verbose == 1)); then
      printf "$success We will run downloads only. Processing...... \n"
    fi
    download
  else
    die "$error No links to download!"
  fi
elif ((task == 2)) && [[ $url_base == false ]]; then #Create Links only
  if ((verbose == 1)); then
    printf "$success Wiping old Links"
  fi
  echo " " > "$base_urls_list"
  echo " " > "$raw_urls_list"
  if ((verbose == 1)); then
    printf "$success Generating links. Processing...... \n"
  fi
  generate_links
  if ((verbose == 1)); then
    printf "$success Generating links part 2. Processing...... \n"
  fi
  create_raw_urls
  if [[ -s $raw_urls_list ]]; then
    true
  else
    die "$error No links failed!"
  fi
elif ((task == 3)); then #Create links and then download
  if ((verbose == 1)); then
    printf "$success Generating links. Processing...... \n"
  fi
  generate_links
  if ((verbose == 1)); then
    printf "$success Generating links part 2. Processing...... \n"
  fi
  create_raw_urls
  if [[ -s $raw_urls_list ]]; then
    if ((verbose == 1)); then
      printf "$success Download time!. Processing...... \n"
    fi
    download
  else
    die "$error No links to download!"
  fi
fi
#end program
