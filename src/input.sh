# input
# (k) Chiave: stringa base64 ( 8BLJdGh1bD03CLNoAwOwVljJaBj7Qmc9O9q )
# (i) Reset id: elimina l'ID di Csync2
# (r) Reset DB: eleimina il DB di Csync2

key=$CSYNC2_KEY

while getopts "k:" opt; do
  case $opt in
		k)
			key=$(echo $OPTARG | tr -d '[[:space:]]')
			;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

[ -z "$key" ] && echo "Key is missing, define with -k" && exit 1
