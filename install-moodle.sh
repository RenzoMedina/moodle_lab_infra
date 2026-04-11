#!/bin/bash
set -e

echo ">>> Verified PHP 8.3 is installed"
until /usr/bin/php8.3 --version > /dev/null 2>&1; do
    echo ">>> Waiting for PHP 8.3 to be installed..."
    sleep 5
done
echo ">>> PHP 8.3 is installed"