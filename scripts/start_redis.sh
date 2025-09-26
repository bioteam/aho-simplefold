#!/bin/bash

# © 2025 BioTeam, LLC All rights reserved.
# Start Redis server in background, dbfilename can't be an absolute path
# First change to the directory where the database file is located
cd /app
redis-server --dbfilename ccd.rdb --port 7777 --daemonize yes --protected-mode no

# Wait for Redis to start
sleep 2

cd /app/ml-simplefold

# Execute the main command
exec "$@"
