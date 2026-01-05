#!/bin/bash

# Licencja: MIT
# Autor: Patryk Jarominski
# converter.sh
# Skrypt do pobierania multimediów z podanej strony (np. YouTube) przy użyciu yt-dlp.

# ===================== #
#     Funkcje pomocy    #
# ===================== #

show_help() {
    zenity --info --title="Pomoc" --text="Użycie: converter.sh\n\nOpcje:\n-v    Wersja i autor\n-h    Pomoc\nSkrypt korzysta z pliku konfiguracyjnego converter.rc"
    exit 0
}

show_version() {
    zenity --info --title="Wersja" --text="converter.sh\nAutor: Patryk Jarominski"
    exit 0
}

# ===================== #
#     Ścieżki TMP       #
# ===================== #
TMP_DIR=$(mktemp -d /tmp/converter.XXXXXX)
TMP_LOG="$TMP_DIR/download.log"
trap 'rm -rf "$TMP_DIR"' EXIT

# ===================== #
#   Wczytanie configu   #
# ===================== #
CONFIG_FILE="./converter.rc"

if [[ ! -f "$CONFIG_FILE" ]]; then
    zenity --error --title="Błąd konfiguracji" --text="Brak pliku konfiguracyjnego: $CONFIG_FILE"
    exit 1
fi

# Wczytaj z pliku .rc
source "$CONFIG_FILE"

# ===================== #
# Obsługa opcji -v i -h #
# ===================== #
while getopts ":vh" opt; do
    case ${opt} in
        v ) show_version ;;
        h ) show_help ;;
        \? ) zenity --error --text="Nieznana opcja: -$OPTARG"; exit 1 ;;
    esac
done
shift $((OPTIND -1))

# ===================== #
#     GUI z Zenity      #
# ===================== #

URL=$(zenity --entry --title="Podaj URL" --text="Wklej adres URL do filmu lub listy odtwarzania:" --entry-text="${DEFAULT_URL:-}")

if [[ -z "$URL" ]]; then
    zenity --error --text="Nie podano adresu URL."
    exit 1
fi

TYPE=$(zenity --list --radiolist \
    --title="Wybierz typ" \
    --text="Co chcesz pobrać?" \
    --column="Wybór" --column="Typ" \
    $( [[ "$TYPE" == "audio" ]] && echo "TRUE" || echo "FALSE" ) "audio" \
    $( [[ "$TYPE" == "video" ]] && echo "TRUE" || echo "FALSE" ) "video")

if [[ -z "$TYPE" ]]; then
    zenity --error --text="Nie wybrano typu."
    exit 1
fi

OUTPUT_DIR=$(zenity --file-selection --directory --title="Wybierz katalog docelowy" --filename="$OUTPUT_DIR/")

# ===================== #
#     Pobieranie pliku  #
# ===================== #

# Logowanie
{
    echo "URL: $URL"
    echo "Typ: $TYPE"
    echo "Katalog docelowy: $OUTPUT_DIR"
    echo "Data i czas pobrania: $(date)"
} > "$TMP_LOG"

(
    echo "# Rozpoczynam pobieranie..."
    if [[ "$TYPE" == "audio" ]]; then
        yt-dlp -x --audio-format mp3 -o "$OUTPUT_DIR/%(title)s.%(ext)s" "$URL" 2>>"$TMP_LOG"
    else
        yt-dlp -f mp4 -o "$OUTPUT_DIR/%(title)s.%(ext)s" "$URL" 2>>"$TMP_LOG"
    fi
    echo "100"
) | zenity --progress --title="Pobieranie" --text="Pobieranie w toku..." --percentage=0 --auto-close

# ===================== #
#     Sprawdzenie stanu #
# ===================== #
if [[ $? -eq 0 ]]; then
    zenity --info --text="Plik został pobrany pomyślnie."
else
    zenity --error --text="Wystąpił błąd podczas pobierania. Szczegóły w logu:\n$TMP_LOG"
    exit 2
fi
