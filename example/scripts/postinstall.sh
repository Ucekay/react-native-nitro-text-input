#!/bin/bash

folders=(
  "./node_modules/react-native-nitro-text-input/example"
  "./node_modules/react-native-nitro-text-input/node_modules"
)

for folder in "${folders[@]}"; do
  if [ -d "$folder" ]; then
    echo "Removing $folder"
    rm -rf "$folder"
  else
    echo "Folder $folder does not exist, skipping"
  fi
done

echo "Post-install completed."
exit 0
