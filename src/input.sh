# input
# (k) Chiave: stringa base64 ( 8BLJdGh1bD03CLNoAwOwVljJaBj7Qmc9O9q )
# (d) Directories: lista di directory to sync ( /opt/data/,/opt/data2 )
# (i) Reset id: elimina l'ID di Csync2
# (r) Reset DB: eleimina il DB di Csync2

key=$CSYNC2_KEY
dirsString=$CSYNC2_DIRS

while getopts "k:d:" opt; do
  case $opt in
		k)
			key=$(echo $OPTARG | tr -d '[[:space:]]')
			;;
		d)
			dirsString=$(echo $OPTARG | tr -d '[[:space:]]')
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

[ -z "$key" ] && echo "Key is missing, define with -k" && exit 1
[ -z "$dirsString" ] && echo "Dirs is missing, define with -d" && exit 1
