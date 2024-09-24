# load necessary libraries
library(plumber)
library(mongolite)
library(jsonlite)
library(enviPat)
# load necessary data
data("isotopes")

#* @apiTitle MS database API
#* @apiDescription API to interact with a MongoDB database containing the data of a MS measurement

#* Retrieve a list of all compounds
#* @get /compounds
#* @response 200 returns a list of all compounds in a JSON format
function() {
  client <- mongo(collection = "compounds", db = "database",
                  url = "mongodb://localhost")
  compounds <- client$find(query = "{}")
  rm(client)
  return(compounds)
}

#* Retrieve a list of all measured compounds
#* @get /measured-compounds
#* @response 200 returns a list of all measured compounds in a JSON format
function() {
  client <- mongo(collection = "measured_compounds", db = "database",
                  url = "mongodb://localhost")
  measured_compounds <- client$find(query = "{}")
  rm(client)
  return(measured_compounds)
}

#* Add a new compound to MongoDB from a JSON file, get MF from compounds document, calculate measured mass from MF and adduct_id
#* @post /measured-compounds
#* @param data The JSON data input
#* @response 201 Compound successfully added
#* @response 404 JSON file not valid
function(data) {
  compound_data <- fromJSON(data[1])
  # check if json file is consistent
  if (ncol(compound_data) != 5) {
    #res$status <- 404
    return(list(message = "JSON file is missing information."))
  }
  if (!any(c("compound_id",
             "retention_time",
             "molecular_formula",
             "comment", "adduct_name") %in% colnames(compound_data))) {
    #res$status <- 404
    return(list(message = "JSON file has different information."))
  }
  # get compounds id from database
  client <- mongo(collection = "compounds", db = "database",
                  url = "mongodb://localhost")
  # Find all compound_names in collection compounds
  compounds <- client$find(query = "{}", fields = '{"compound_id": 1}')
  # check if compound id is existing in the compound database
  if (!compound_data$compound_id %in% compounds$compound_id) {
    #res$status <- 404
    return(list(message = "Compound_id not found in compound database, 
                please add compound_id first."))
  }
  # check if retention time value is positive
  if (compound_data$retention_time < 0) {
    #res$status <- 404
    return(list(message = "Retention time needs to be positive."))
  }
  # check retention_time_id values in database
  client <- mongo(collection = "rt", db = "database",
                  url = "mongodb://localhost")
  # find all retention_time_id in collection rt
  rt_id <- client$find(query = "{}", fields = '{"retention_time_id": 1}')
  # assign retention_time_id
  retention_time_id <- max(as.numeric(rt_id$retention_time_id)) + 1
  # check if valid adduct is applied and retrieve adduct_id
  client <- mongo(collection = "adducts", db = "database",
                  url = "mongodb://localhost")
  adducts <- client$find("{}")  # Find all names in collection adducts
  # check if compound id is existing in the compound database
  if (!compound_data$adduct_name %in% adducts$adduct_name) {
    #res$status <- 404
    return(list(message = "Adduct type is not supported."))
  }
  # get adduct_id
  adduct_id <- adducts$adduct_id[which(adducts$adduct_name == compound_data$adduct_name)]
  # calculate measured_mass
  check_compounds <- check_chemform(isotopes, compound_data$molecular_formula)
  if (any(check_compounds$warning)) {
    return(list(message = "Non-valid molecular formulas found in compound file."))
  }
  # check measurement_id values in database
  client <- mongo(collection = "measured_compounds", db = "database",
                  url = "mongodb://localhost")
  # find all measured_compounds_id in collection measured_compounds
  measured <- client$find(query = "{}", fields = '{"measured_compound_id": 1, "compound_id": 1}')
  # check if compound_id was measured previously
  if (compound_data$compound_id %in% measured$compound_id) {
    return(list(message = "Compound_id is already in measurment database."))
  }
  # assign retention_time_id
  measured_compound_id <- max(as.numeric(measured$measured_compound_id), na.rm = TRUE) + 1
  # build input entry for measured compounds collection
  measured_compounds_input <- data.frame(measured_compound_id = as.integer(measured_compound_id),
                                         compound_id = as.integer(compound_data$compound_id),
                                         retention_time_id = as.integer(retention_time_id),
                                         adduct_id = as.integer(adduct_id),
                                         measured_mass = check_compounds$monoisotopic_mass,
                                         molecular_formula = compound_data$molecular_formula)
  # add measurement to measured_compounds
  client$insert(measured_compounds_input)
  # add retention_time and comment to rt
  client <- mongo(collection = "rt", db = "database",
                  url = "mongodb://localhost")
  rt_input <- data.frame(retention_time_id = as.integer(retention_time_id),
                         retention_time = as.numeric(compound_data$retention_time),
                         comment = as.character(compound_data$comment))
  client$insert(rt_input)
  rm(client)
  #res$status <- 201
  return(list(message = "New compound added successfully!"))
}

#* Fetch a compound based on query parameters
#* @get /measured-compounds-query
#* @param query_params parameters as json file, with retention_time_min, retention_time_max, type and ion_mode as parameters supported. Retention time thresholds should be given in minutes
#* @response 200 Returns matching compounds in JSON format
#* @response 404 No matching compound not found
function(query_params) {
  # load query parameters
  query_data <- fromJSON(query_params[1])
  # open measurement collection and query for given selections of ids
  client <- mongo(collection = "measured_compounds", db = "database",
                  url = "mongodb://localhost")
  measured_compounds <- client$find(query = "{}")
  # check if RT information is a valid query in json_file, if yes, get valid retention_time id from rt collection
  if (sum(c("retention_time_min", "retention_time_max") %in% colnames(query_data))) {
    # create connection, query for values between given values
    client <- mongo(collection = "rt", db = "database",
                    url = "mongodb://localhost")
    # get all compound ids that fulfill the requirement
    rt_query <- paste0("{\"retention_time\" : {\"$gt\": ",
                       as.numeric(query_data$retention_time_min),
                       ",\"$lt\": ",
                       as.numeric(query_data$retention_time_max),
                       "}}")
    retention_time_ids <- client$find(query = rt_query,
                                      fields = '{"retention_time_id" : 1}')
    # close database connection
    rm(client)
    # filter measured_compounds
    if (length(retention_time_ids) > 1) {
      measured_compounds <- measured_compounds[which(measured_compounds$retention_time_id %in% retention_time_ids$retention_time_id), ]
    }else {
      message("No results found for Retention time values applied.")
    }
  }else {
    message("No retention time query perfomed.")
  }
  # check if type is given as query in query_param, if yes, get valid compound_id from compound collection
  if ("type" %in% colnames(query_data)) {
    # create connection, query for same type
    client <- mongo(collection = "compounds", db = "database",
                    url = "mongodb://localhost")
    # get all compound_ids that fulfill the requirement
    type_query <- paste0('{"type" : "', as.character(query_data$type), '"}')
    compound_ids <- client$find(query = type_query, fields = '{"compound_id" : 1}')
    # close database connection
    rm(client)
    # filter measured_compounds
    if (length(compound_ids) > 1) {
      measured_compounds <- measured_compounds[which(measured_compounds$compound_id %in% compound_ids$compound_id), ]
    }else {
      message("No results found for the type value applied.")
    }
  }else {
    message("No query on type perfomed.")
  }
  # check if ion_mode is given as a query in query_param
  if ("ion_mode" %in% colnames(query_data)) {
    # create connection, query for same ion_mode
    client <- mongo(collection = "adducts", db = "database",
                    url = "mongodb://localhost")
    # get all compound_ids that fulfill the requirement
    ion_query <- paste0('{"ion_mode" : "', as.character(query_data$ion_mode), '"}')
    adduct_ids <- client$find(query = ion_query, fields = '{"adduct_id" : 1}')
    # close database connection
    rm(client)
    # filter measured_compounds
    if (length(adduct_ids) > 1) {
      measured_compounds <- measured_compounds[which(measured_compounds$adduct_id %in% adduct_ids$adduct_id), ]
    }else {
      message("No results found for ion_mode values applied.")
    }
  }else {
    message("No query on ion _mode perfomed.")
  }
  return(measured_compounds)
}
