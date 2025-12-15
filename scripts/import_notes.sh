# -- import notes from my obsidian vault
#!/bin/bash
VAULT_PATH=$HOME/Vault
NOTES_PATH=$VAULT_PATH/Languages
ROOT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )


echo "Importing notes from" $NOTES_PATH "into" $ROOT_DIR

cp -r $NOTES_PATH/* $ROOT_DIR/ 
