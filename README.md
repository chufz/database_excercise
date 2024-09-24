# database

This repository contains an example solution for a database solution in mass spectrometry applications.


# Requirements

Previous to running the scripts, the following requirements need to be installed:

For initiating the database with `R/init_database.R` and for running the API (`API.R`and `run_API.R`) :

```{R}
install.packages("eniPat")
install.packages("readxl")
install.packages("jsonlite")
install.packages("mongolite")
install.packages("plumber")
```
Additionally, you need to install mongoDB, a detailed installation guide can be found at [here](https://www.mongodb.com/docs/manual/administration/install-on-linux/)

# Structure

The repository contains of the following files:

 - `R/init_database.R` for creating the mongoDB database from a data_iput directory, containing the excel files `compounds.xlsx` and `measured_compounds.xlsx` and a json file defining the adducts (`adducts.json`).

 - The API can be started in the terminal, using the bash script:
 `./start_API.sh`
 
 - To present the function of the API, run the bash script `./test_API.sh`
 
 
 
# Usage

A documentation of the API can be found using

the running swagger Docs at http://127.0.0.1:8000/__docs__/
