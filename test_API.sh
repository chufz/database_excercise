#!/bin/bash

# endpoint GET /compounds - Retrieve a list of all compounds
echo " "
echo "#####################"
echo "# list of compounds #"
echo "#####################"
curl http://127.0.0.1:8000/compounds | python -m json.tool | head

# endpoint GET /measured-compounds - Retrieve a list of all measured compounds
echo " "
echo "##############################"
echo "# list of measured_compounds #"
echo "##############################"
curl http://127.0.0.1:8000/measured-compounds | python -m json.tool | head

# endpoint POST /measured-compounds - Add a new measured compound to the database
echo " "
echo "###############################"
echo "# add compound from json file #"
echo "###############################"
curl --request POST  --url http://127.0.0.1:8000/measured-compounds --data-urlencode 'data=~/git/databases/new_compound.json'

# endpoint GET /measured-compounds?query_params= - Filter compounds based on the query parameters retention_time, type and ion_mode.
echo " "
echo " "
echo "##########################"
echo "# get query of compounds #"
echo "##########################"
curl  --request GET --url http://127.0.0.1:8000/measured-compounds-query --data-urlencode 'query_params=~/git/databases/query_example.json'


echo " "
echo " "
