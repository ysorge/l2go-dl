#!/bin/bash

# Function to print usage information
print_help() {
    echo "Usage: $0 [-m] [-p password | --password password] [-h | --help] [URL]"
    echo "  -m, --merge       Merge all chunklists into a single video file"
    echo "  -p, --password    Password for the video page"
    echo "  -h, --help        Display this help message"
    echo "  URL               URL of the video page (can be provided as the last argument)"
}

# Function to check if a string is a valid URL
is_valid_url() {
    if [[ $1 =~ ^https?:// ]]; then
        return 0
    else
        return 1
    fi
}

# Function to draw a progress bar in one line
draw_progress_bar() {
  local progress=$1
  local total=$2
  local width=50
  local completed=$((progress * width / total))
  local remaining=$((width - completed))
  
  printf "\r["
  for ((i = 0; i < completed; i++)); do
    printf "#"
  done
  for ((i = 0; i < remaining; i++)); do
    printf " "
  done
  printf "] %d/%d" "$progress" "$total"
}

# Parse the command-line options
merge_all=false
password=""
video_page_url=""

while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -m|--merge)
            merge_all=true
            shift
            ;;
        -p|--password)
            password="$2"
            shift
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            if is_valid_url "$key"; then
                video_page_url="$key"
                shift
            else
                echo "Unknown option or invalid URL: $1"
                print_help
                exit 1
            fi
            ;;
    esac
done

# Prompt the user for the video page URL if not provided
if [ -z "$video_page_url" ]; then
    read -p "Enter the video page URL: " video_page_url
    if ! is_valid_url "$video_page_url"; then
        echo "Error: Invalid URL."
        print_help
        exit 1
    fi
fi

# Prompt the user for the password if not provided
if [ -z "$password" ]; then
    read -s -p "Enter the password: " password
    echo
fi

# Extract the base name for the output videos
base_name=$(basename "$video_page_url")

# Get the current timestamp in milliseconds
timestamp=$(($(date +%s%N)/1000000))

# Perform the POST request to access the video page and save the resulting HTML
echo -n "Request video page with password ... "
html_response=$(curl -s "$video_page_url" -X POST \
    -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:125.0) Gecko/20100101 Firefox/125.0' \
    -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' \
    -H 'Accept-Language: de,en-US;q=0.7,en;q=0.3' \
    -H 'Accept-Encoding: gzip, deflate, br' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H 'Origin: https://lecture2go.uni-hamburg.de' \
    -H 'DNT: 1' \
    -H 'Connection: keep-alive' \
    -H "Referer: $video_page_url" \
    -H 'Upgrade-Insecure-Requests: 1' \
    -H 'Sec-Fetch-Dest: document' \
    -H 'Sec-Fetch-Mode: navigate' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'Sec-Fetch-User: ?1' \
    --data-raw "_OpenAccessVideos_formDate=$timestamp&_OpenAccessVideos_password=$password&_OpenAccessVideos_tryauth=1")
if [ -z "$html_response" ]; then
    echo "Failed"
    echo "Error: Failed to fetch the video page. Please check the URL and try again."
    exit 1
else
    echo "OK"
fi

# Extract the playlist .m3u8 URL from the HTML response
echo -n "Extract playlist URL ... "
playlist_url=$(echo "$html_response" | grep -oP '(?<=convertVideoUrls\(\[{"file":")[^"]*(?="})')
if [ -z "$playlist_url" ]; then
    echo "Failed"
    echo "Error: Failed to extract the playlist URL from the video page."
    exit 1
else
    echo "OK"
fi

# Download the main playlist .m3u8 file
echo -n "Download playlist URL ... "
if curl -s -O "$playlist_url"; then
    echo "OK"
elif [ $? -ne 0 ]; then
    echo "Failed"
    echo "Error: Failed to download the playlist file."
    exit 1
else
    echo "Failed"
    exit 1
fi

# Extract all chunklist URLs from the playlist file
echo -n "Extract chunklist URLs from playlist file ... "
chunklists=$(grep -o 'chunklist_.*\.m3u8' $(basename "$playlist_url"))
if [ -z "$chunklists" ]; then
    echo "Failed"
    echo "Error: No chunklists found in the playlist file."
    exit 1
else
    echo "OK"
fi

# Define base URL for chunks
base_url=$(dirname "$playlist_url")/

# Initialize a temporary directory for downloaded chunks
temp_dir=$(mktemp -d -p .)

# Function to download chunks for a given chunklist and append to the file list
download_chunks() {
    local chunklist_url=$1
    local filelist=$2
    
    echo -n "Download chunklist file ... "
    if curl -s -o "${temp_dir}/$(basename "$chunklist_url")" "$chunklist_url"; then
        echo "OK"
    elif [ $? -ne 0 ]; then
        echo "Failed"
        echo "Error: Failed to download the chunklist file."
        exit 1
    else
        echo "Failed"
        exit 1
    fi
    
    chunklist_file="${temp_dir}/$(basename "$chunklist_url")"

    # Count total number of chunks
    total_chunks=$(grep -c '.ts$' "$chunklist_file")
    
    # Initialize progress counter
    progress=0

    echo "Download chunks ..."
    
    # Read the chunklist file and download each chunk
    while IFS= read -r line; do
        if [[ $line == *.ts ]]; then
            chunk_url="${base_url}${line}"
            chunk_file="${temp_dir}/${line}"
            curl -s -o "$chunk_file" "$chunk_url"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to download chunk $line."
                exit 1
            fi
            echo "file '${line}'" >> "$filelist"
            
            # Update and draw progress bar
            progress=$((progress + 1))
            draw_progress_bar $progress $total_chunks
        fi
    done < "$chunklist_file"
    
    # Print a newline after the progress bar is complete
    echo
}

# Process each chunklist
index=1
if [ "$merge_all" = true ]; then
    # Merge all chunklists into a single video file
    filelist="${temp_dir}/filelist.txt"
    for chunklist in $chunklists; do
        chunklist_url="${base_url}${chunklist}"
        download_chunks "$chunklist_url" "$filelist"
    done
    # Combine all .ts files into a single video file
    ffmpeg -f concat -safe 0 -i "$filelist" -c copy "${base_name}.mp4"
else
    # Create one video per chunklist
    for chunklist in $chunklists; do
        filelist="${temp_dir}/filelist${index}.txt"
        touch "$filelist"  # Ensure the filelist file exists before writing to it
        chunklist_url="${base_url}${chunklist}"
        download_chunks "$chunklist_url" "$filelist"
        # Combine all .ts files into a single video file
        ffmpeg -f concat -safe 0 -i "$filelist" -c copy "${base_name}-${index}.mp4"
        ((index++))
    done
fi

# Clean up the temporary directory
echo -n "Clean up temporary directory ... "
rm -rf "$temp_dir"
rm $(basename "$playlist_url")
echo "OK"
