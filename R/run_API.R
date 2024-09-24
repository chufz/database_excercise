# Load plumber and run the API
library(plumber)
# Load the API file
r <- plumb("~/git/databases/R/API.R")
# Run the API on port 8000
r$run(port=8000)