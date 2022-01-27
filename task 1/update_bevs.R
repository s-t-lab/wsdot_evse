
update_wa_bevs <- function() {

  # Database settings -------------------------------------------------------

  main_con <- DBI::dbConnect(
    RPostgres::Postgres(),
    host = Sys.getenv("MAIN_HOST"),
    dbname = Sys.getenv("MAIN_DB"),
    user = Sys.getenv("MAIN_USER"),
    password = Sys.getenv("MAIN_PWD"),
    port = Sys.getenv("MAIN_PORT")
  )

  # Download EV data from WA DOL - needs an SOCRATA APP TOKEN.
  wa_evs <-
    RSocrata::read.socrata("https://data.wa.gov/resource/f6w7-q2d2.csv",
                           app_token = Sys.getenv('SOCRATA_APP_TOKEN'))

  # Filter out BEVs
  wa_bevs <- wa_evs %>% tibble::as_tibble() %>%
    dplyr::filter(agrepl("Battery Electric Vehicle (BEV)", .data$ev_type))

  wa_bevs <-
    wa_bevs %>% dplyr::select(-c('vin_1_10', 'cafv_type', 'ev_type', 'geocoded_column')) %>% dplyr::rename('veh_id' = 'dol_vehicle_id')

  # Get fuel-economy data from fueleconomy.gov
  tmp <- tempfile(fileext = ".zip")
  download.file("https://www.fueleconomy.gov/feg/epadata/vehicles.csv.zip",
                tmp,
                quiet = TRUE)
  unzip(tmp, exdir = "data-raw")

  raw_vehicles_data <- read.csv("data-raw/vehicles.csv")

  ev_tbl <- raw_vehicles_data %>%
    tibble::as_tibble() %>%
    dplyr::select(
      .data$id,
      .data$make,
      .data$model,
      .data$year,
      fuel = fuelType,
      fuel_consumption = .data$combE,
      .data$range
    ) %>%
    dplyr::mutate(make = tolower(make), model = tolower(model)) %>%
    dplyr::filter(.data$fuel == "Electricity") %>%
    dplyr::arrange(make, model, year)

  wa_bevs$range <- NA
  wa_bevs$capacity <- NA
  wa_bevs$fuel_consumption <- NA

  for (i in 1:nrow(wa_bevs)) {
    cur_make <- tolower(wa_bevs$make[i])
    cur_model <- tolower(wa_bevs$model[i])
    cur_year <- wa_bevs$model_year[i]

    ev_df <-
      subset(ev_tbl,
             year == cur_year &
               agrepl(cur_make, make) &
               agrepl(cur_model, model))
    # print(ev_df)
    if (is.data.frame(ev_df) && nrow(ev_df) == 0) {
      wa_bevs$range[i] <- NA
      wa_bevs$capacity[i] <- NA
    } else {
      wa_bevs$range[i] <- mean(ev_df$range)
      wa_bevs$capacity[i] <-
        mean(ev_df$range) * mean(ev_df$fuel_consumption) / 100
      wa_bevs$fuel_consumption[i] <- mean(ev_df$fuel_consumption)
    }
  }

  wa_bevs_new <- wa_bevs %>% dplyr::filter(.data$model_year > 2008)
  wa_bevs_man <- wa_bevs_new

  # Remove Tesla Roadster
  wa_bevs_man <-
    wa_bevs_man[-which(tolower(wa_bevs_man$model) == "roadster"),]

  wa_bevs_man$range[which(tolower(wa_bevs_man$make) == "azure dynamics")] <- 56
  wa_bevs_man$capacity[which(tolower(wa_bevs_man$make) == "azure dynamics")] <-
    56 * 54 / 100
  wa_bevs_man$fuel_consumption[which(tolower(wa_bevs_man$make) == "azure dynamics")] <-
    54

  # Toyota RAV4
  wa_bevs_man$range[which(tolower(wa_bevs_man$make) == "toyota" &
                            tolower(wa_bevs_man$model) == "rav4 ev 2wd")] <-
    103
  wa_bevs_man$capacity[which(tolower(wa_bevs_man$make) == "toyota" &
                               tolower(wa_bevs_man$model) == "rav4 ev 2wd")] <-
    103 * 46 / 100
  wa_bevs_man$fuel_consumption[which(tolower(wa_bevs_man$make) == "toyota" &
                                       tolower(wa_bevs_man$model) == "rav4 ev 2wd")] <-
    46
  
  # Kia Niro
  wa_bevs_man$range[which(tolower(wa_bevs_man$make) == "kia" &
                            tolower(wa_bevs_man$model) == "niro")] <-
    239
  wa_bevs_man$capacity[which(tolower(wa_bevs_man$make) == "kia" &
                               tolower(wa_bevs_man$model) == "niro")] <-
    239 * 30 / 100
  wa_bevs_man$fuel_consumption[which(tolower(wa_bevs_man$make) == "kia" &
                                       tolower(wa_bevs_man$model) == "niro")] <-
    30
  
  # Mercedes B-Class
  wa_bevs_man$range[which(tolower(wa_bevs_man$make) == "mercedes-benz" &
                            tolower(wa_bevs_man$model) == "b-class")] <-
    87
  wa_bevs_man$capacity[which(tolower(wa_bevs_man$make) == "mercedes-benz" &
                               tolower(wa_bevs_man$model) == "b-class")] <-
    87 * 40 / 100
  wa_bevs_man$fuel_consumption[which(tolower(wa_bevs_man$make) == "mercedes-benz" &
                                       tolower(wa_bevs_man$model) == "b-class")] <-
    40
  
  # Problem cars with many owners in WA without data in database (these are removed)
  # Ford F150, Mitsubishi Outlander

  ## Manually assigning the Connector type codes
  wa_bevs_man$connector_code <- NA
  # Tesla is 4
  wa_bevs_man$connector_code[which(tolower(wa_bevs_man$make) == "tesla")] <-
    4

  # BMW, Chevrolet, Mercedes, Volkswagen are SAE Combo - 2
  combo_connector_makes <-
    tolower(c(
      'BMW',
      'Volkswagen',
      'Chevrolet',
      'Mercedes-Benz',
      'Ford',
      'Jaguar',
      'Audi',
      'MINI'
    ))
  wa_bevs_man$connector_code[which(tolower(wa_bevs_man$make) %in% combo_connector_makes)] <-
    2

  # Nissan, Mitsubishi, etc. are ChaDemo - 1
  chademo_connector_makes <-
    tolower(c('Nissan', 'Mitsubishi', 'Toyota', 'Kia', 'Honda', 'Hyundai'))
  wa_bevs_man$connector_code[which(tolower(wa_bevs_man$make) %in% chademo_connector_makes)] <-
    1

  # Remove EVs that do not have fast charging
  wa_bevs_man2 <-
    wa_bevs_man %>%
    dplyr::filter(!(tolower(.data$make) == "fiat")) %>%
    dplyr::filter(!(tolower(.data$model) == "coda")) %>%
    dplyr::filter(!(tolower(.data$make) == "azure dynamics")) %>%
    dplyr::filter(!(tolower(.data$make) == "smart")) %>%
    dplyr::filter(!(tolower(.data$model) == "life")) %>%
    dplyr::filter(!(tolower(.data$make) == "th!nk"))

  # Some NAs remain in `base_msrp` and `legislative_district`
  wa_bevs_man3 <-
    wa_bevs_man2 %>% tidyr::replace_na(replace = list(base_msrp = 0, legislative_district = 0))
  wa_bevs_man4 <- wa_bevs_man3[complete.cases(wa_bevs_man3), ]
  wa_bevs_man4 <- wa_bevs_man4 %>% dplyr::rename('range_fe' = 'range')

  # Convert veh_id to char
  wa_bevs_man4$veh_id <- as.character(wa_bevs_man4$veh_id)

  DBI::dbBegin(main_con)
  DBI::dbWriteTable(main_con, "wa_bevs", wa_bevs_man4, overwrite = TRUE)

  res <- main_con %>% DBI::dbSendQuery(
    paste0(
      "insert into table_stats (table_name, last_updated) values ('wa_bevs', '",
      as.character(Sys.time()),
      "') on conflict (table_name) do update set last_updated = EXCLUDED.last_updated;"
    )
  )
  DBI::dbClearResult(res)
  DBI::dbCommit(main_con)
  DBI::dbDisconnect(main_con)
}
