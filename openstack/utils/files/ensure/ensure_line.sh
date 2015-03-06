#!/bin/bash

thefile="$1"
target="$2"

echo looking for "$target" in "$thefile"

if !(grep -w "$target" "$thefile"); then
    echo $? aha
    echo "$target" >> "$thefile"
fi
