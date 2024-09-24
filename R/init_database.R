# load necessary libraries
library(enviPat)
library(readxl)
library(jsonlite)
library(mongolite)

# load necessary data
data("isotopes")

# define were input files are stored
# change if the script is run on a different system
compounds_filepath <- "input_data/compounds.xlsx"
adducts_filepath <- "input_data/adducts.json"
measurment_filepath <- "input_data/measured-compounds.xlsx"

# load in compounds database
compounds <- read_excel(compounds_filepath)

# test if required column are present
val_col <- c("compound_id", "compound_name", "molecular_formula", "type")
if (any(!val_col %in% colnames(compounds))) {
  message("colnames of compound file do not fullfill the requirements")
}

# put compound_id as integer value
compounds$compound_id <- as.integer(compounds$compound_id)

# keep only unique entries
if (any(duplicated(compounds))) {
  message("duplicated rows found in compound file")
}

if (any(duplicated(compounds$compound_id))) {
  message("duplicated compound_id found in compound file")
}

# check molecular formula for consistency
check_compounds <- check_chemform(isotopes, compounds$molecular_formula)
if (any(check_compounds$warning)) {
  message(paste("non-valid molecular formulas found in compound file: ",
          check_compounds$new_formula[which(check_compounds$warning == TRUE)]))
}

# calculate required molecular information
compounds$computed_mass <- check_compounds$monoisotopic_mass

#########

# load in adduct table as json file
adducts <- fromJSON(adducts_filepath)

# test if json file is valid
if (any(lapply(adducts, length) != 3)) {
  message("adduct file is missing information")
}

if (any(!c("name", "mass", "ion_mode") %in% colnames(adducts))) {
  message("entries in adduct file missing")
}

# keep mass in numeric format
adducts$mass <- as.numeric(adducts$mass)

# change name to adduct_name
names(adducts)[names(adducts) == "name"] <- "adduct_name"

# change mass to mass_adjustment
names(adducts)[names(adducts) == "mass"] <- "mass_adjustment"

# add adduct_id as first row
adducts <- cbind(adduct_id = seq_len(nrow(adducts)), adducts)

#########

# load in measured table
measurment <- read_excel(measurment_filepath)

# test if file is valid
if (any(!c("compound_id",
           "compound_name",
           "retention_time",
           "retention_time_comment",
           "adduct_name",
           "molecular_formula") %in% colnames(measurment))) {
  message("Colnames of measurment file do not fullfill the requirements")
}

# put compound_id as integer value
measurment$compound_id <- as.integer(measurment$compound_id)

# check that retention times are positive values
if (any(measurment$retention_time < 0)) {
  message("Retention time values that are not positive are found. 
          Please revise entry file")
}

# keep entries without comment similar
measurment$retention_time_comment[which(is.na(measurment$retention_time_comment))] <- "nan"

# remove entries with white spaces in molecular formula string
if (any(grepl("^\\S+\\s+", measurment$molecular_formula))) {
  message("Entry with invalid molecular formula was removed from measument input file")
  measurment <- measurment[-grep("^\\S+\\s+", measurment$molecular_formula), ]
}

# calculate mono-isotopic mass
measurment_check <- check_chemform(isotopes, measurment$molecular_formula)
if (any(measurment_check$warning)) {
  message(paste("Non-valid molecular formulas found in compound file: ",
                measurment_check$new_formula[which(check$warning == TRUE)]))
}

# calculate m/z value based on adduct
measurment$mass <- measurment_check$monoisotopic_mass
measurment$calculated_mass <- NA

# create adduct_id
measurment$adduct_id <- NA

# loop over all adduct_names which are supported, aslo add adduct_id
for (i in which(measurment$adduct_name %in% adducts$adduct_name)) {
  which_adduct <- which(adducts$adduct_name == measurment$adduct_name[i])
  measurment$adduct_id[i] <- adducts$adduct_id[which_adduct]
}

# assign retention_time_id for all entries with same rt but different adducts
n <- 1
measurment$retention_time_id <- NA
for (i in unique(measurment$compound_id)) {
  # get compounds that are in table
  same_comp_row <- which(measurment$compound_id == i)
  # check if the RT is same for same compound_id
  if (length(unique(measurment$retention_time[same_comp_row])) > 1) {
    message("Found different Rt values for same compound_id, 
            only keeping first entry")
  }
  if (length(unique(measurment$retention_time_comment[same_comp_row])) > 1) {
    message("Found different Rt comment for same compound_id, 
            only keeping first entry")
  }
  # assign retention_time_id
  measurment$retention_time_id[same_comp_row] <- n
  n <- n + 1
}

# keep retention time as integer value
measurment$retention_time_id <- as.integer(measurment$retention_time_id)

# create measurement table for database
measured_compounds <- data.frame(measured_compound_id = seq_len(nrow(measurment)), 
                                 compound_id = measurment$compound_id,
                                 retention_time_id = measurment$retention_time_id,
                                 adduct_id = measurment$adduct_id,
                                 measured_mass = measurment$mass,
                                molecular_formula = measurment$molecular_formula)

# create rt table for database
rt <- data.frame(retention_time_id = measured_compounds$retention_time_id,
                 retention_time = measurment$retention_time,
                 comment = measurment$retention_time_comment)
rt <- unique(rt)

#########

# create database
# connection to client
# (start mongoDB in Terminal with 'sudo systemctl start mongod')
# check status with 'sudo systemctl status mongod'

# remove previous databases with same name
client <- mongo(db = "database", url = "mongodb://localhost")
for (col in c("compounds", "measured_compounds", "rt", "adducts")) {
  # Create a connection to the specific collection and drop it
  mongo_collection <- mongo(collection = col, db = "database",
                            url = "mongodb://localhost")
  mongo_collection$drop()
}
#check that database is really empty
client <- mongo(db = "database", url = "mongodb://localhost")
client$run('{"listCollections": 1}')$cursor$firstBatch
# insert data to collections
client <- mongo(collection = "compounds", db = "database",
                url = "mongodb://localhost")
client$insert(compounds)
client <- mongo(collection = "measured_compounds", db = "database",
                url = "mongodb://localhost")
client$insert(measured_compounds)
client <- mongo(collection = "rt", db = "database",
                url = "mongodb://localhost")
client$insert(rt)
client <- mongo(collection = "adducts", db = "database",
                url = "mongodb://localhost")
client$insert(adducts)
message("Data inserted into MongoDB.")
rm(client)
#########
