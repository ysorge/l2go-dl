# Lecture2Go Video Downloader

## Overview

The Lecture2Go Video Downloader script is a tool designed to download videos, including 
password-protected ones, from the Lecture2Go video portals. Lecture2Go is an online 
video portal designed for universities, where people can watch, listen to, and download 
recorded lectures. The lecture recording system, developed at the 'Regionales 
Rechenzentrum' (RRZ), makes it possible to synchronously record the speaker and their 
presentation.

## Features

- Download videos from Lecture2Go portals.
- Support for password-protected videos.
- Option to merge all video chunks into a single video file.
- Option to create separate videos for each chunklist.

## Requirements

- [`bash`](https://www.gnu.org/software/bash/)
- [`curl`](https://curl.se/)
- [`ffmpeg`](https://ffmpeg.org/)

## Usage

### Command-line Arguments

- `-p, --password PASSWORD`: Password for the video page.
- `-m, --merge`: Merge all chunklists into a single video file.
- `-h, --help`: Display the help message.
- `url`: URL of the video page (can be provided as the last argument).

### Example Usage

```bash
./l2go-dl.sh --password "your_password" https://lecture2go.uni-hamburg.de/l2go/-/get/v/abc12345
```

## Detailed Steps

1. Clone the repository:

    ```bash
    git clone https://github.com/ysorge/l2go-dl.git
    cd l2go-dl
    ```

2. Make the script executable:

    ```bash
    chmod +x l2go-dl.sh
    ```

3. Run the script with the desired options:

    ```bash
    ./l2go-dl.sh --help
    ```

## License

This project is licensed under the AGPL-3.0 license. See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an Issue.
