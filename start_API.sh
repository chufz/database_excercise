#!/bin/bash

# start mongodb
sudo systemctl start mongod

Rscript R/run_API.R 
