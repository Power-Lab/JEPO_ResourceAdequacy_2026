##################################
##################################
##################################
###Part1: Process (and Record) Flow data

rm(list=ls())

### Prerequisite packages
requiredPackages <- c('dplyr', 'readr')     

for(package in requiredPackages){
  if(!require(package, character.only = TRUE)) install.packages(package)
  library(package, character.only = TRUE)
}

parent_dir <- dirname(getwd())

## Create all necessary path for the scenarios:
PriorityMLT <- file.path(parent_dir, 'Results_ne_2021_PriorityMLT')
MLT <- file.path(parent_dir, 'Results_ne_2021_MLT')
SpotMLT <- file.path(parent_dir, 'Results_ne_2021_SpotMLT')
FlexibleSpotMLT <- file.path(parent_dir, 'Results_ne_2021_FlexibleSpotMLT')

Results_path <- list(
  PriorityMLT,
  MLT, 
  SpotMLT,
  FlexibleSpotMLT
)

# Specify 12 weekly folder names
week_list <- as.character(1:12)

# Define transmission path list
line_list <- c('HL_to_IME', 'HL_to_JL', 'IME_to_JL', 'IME_to_LN', 'JL_to_LN', 'IME_to_SD', 'LN_to_JB') 
# Define maximum transmission capacity for each line
max_transmission_capacity <- c(4500, 3600, 8400, 7200, 3600, 10000, 3000)


for (path in Results_path){
  # Initialize an empty data frame to store data
  all_data <- data.frame()
  # Iterate through each weekly folder
  for (w in week_list){
    # Read the transmission data for each week
    temp_data <- read.csv(file.path(path, w, 'vFlow_results.csv'))
    
    # Start from the third column
    temp_data <- temp_data[, -c(1:2)]
    
    # Check whether the data frame is empty
    if(ncol(temp_data) > 0){
      # If all_data is empty, assign temp_data directly
      if(ncol(all_data) == 0){
        all_data <- temp_data
      } else {
        # Otherwise, append temp_data to the right side of all_data
        all_data <- cbind(all_data, temp_data)
      }
    }
  }

  all_data_transposed <- as.data.frame(t(all_data))
  colnames(all_data_transposed) <- NULL
  
  all_data_abs_transposed <- abs(all_data_transposed)
  
  
  # Step 1: set column names
  colnames(all_data_transposed) <- line_list
  colnames(all_data_abs_transposed) <- line_list
  
  # Step 2: add date column
  start_date <- as.Date("2021-08-09")  # Start date
  end_date <- as.Date("2021-10-31")    # End date
  dates <- seq.Date(start_date, end_date, by="day")  # Generate a sequence of dates
  dates_repeated <- rep(dates, each=24)  # Repeat each date 24 times
  
  # Assume all_data_transposed is already transformed; now add the date column
  all_data_transposed$date <- dates_repeated[1:nrow(all_data_transposed)]  # Only populate existing rows
  all_data_abs_transposed$date <- dates_repeated[1:nrow(all_data_abs_transposed)]  # Only populate existing rows
  
  # Save results to the corresponding path
  write.csv(all_data_transposed, file.path(path, 'Flow_hourly_12Week.csv'), row.names = FALSE)
  write.csv(all_data_abs_transposed, file.path(path, 'FlowABS_hourly_12Week.csv'), row.names = FALSE)

  
  #######Calculate monthly total transmission
    # Read CSV files
    data <- read.csv(file.path(path, 'Flow_hourly_12Week.csv'))
    data_abs <- read.csv(file.path(path, 'FlowABS_hourly_12Week.csv'))
    
    # Ensure the date column uses Date format
    data$date <- as.Date(data$date)
    data_abs$date <- as.Date(data_abs$date)
    
    # Filter data for September and October
    data_sep <- data[data$date >= as.Date("2021-09-01") & data$date <= as.Date("2021-09-30"),]
    data_oct <- data[data$date >= as.Date("2021-10-01") & data$date <= as.Date("2021-10-31"),]
    data_abs_sep <- data_abs[data_abs$date >= as.Date("2021-09-01") & data_abs$date <= as.Date("2021-09-30"),]
    data_abs_oct <- data_abs[data_abs$date >= as.Date("2021-10-01") & data_abs$date <= as.Date("2021-10-31"),]
    
    # Select numeric columns and exclude the date column
    numeric_cols <- sapply(data_sep, is.numeric) & names(data_sep) != "date"

    # Calculate column totals
    total <- colSums(data[, numeric_cols], na.rm = TRUE)
    total_sep <- colSums(data_sep[, numeric_cols], na.rm = TRUE)
    total_oct <- colSums(data_oct[, numeric_cols], na.rm = TRUE)
    
    total_abs <- colSums(data_abs[, numeric_cols], na.rm = TRUE)
    total_abs_sep <- colSums(data_abs_sep[, numeric_cols], na.rm = TRUE)
    total_abs_oct <- colSums(data_abs_oct[, numeric_cols], na.rm = TRUE)
    
    # Save results as CSV files without row names
    write.csv(as.data.frame(t(total)), file.path(path, 'Flow_sum_12Week.csv'), row.names = FALSE)
    write.csv(as.data.frame(t(total_sep)), file.path(path, 'Flow_sum_monthly_09.csv'), row.names = FALSE)
    write.csv(as.data.frame(t(total_oct)), file.path(path, 'Flow_sum_monthly_10.csv'), row.names = FALSE)
    
    write.csv(as.data.frame(t(total_abs)), file.path(path, 'FlowABS_sum_12Week.csv'), row.names = FALSE)
    write.csv(as.data.frame(t(total_abs_sep)), file.path(path, 'FlowABS_sum_monthly_09.csv'), row.names = FALSE)
    write.csv(as.data.frame(t(total_abs_oct)), file.path(path, 'FlowABS_sum_monthly_10.csv'), row.names = FALSE)
    
  ####Calculate line utilization rate
  # Compute line utilization for August, September, and October
  utilization_all <- total_abs / ((23+31+30) * 24 * max_transmission_capacity)
  # Compute line utilization for September
  utilization_sep <- total_abs_sep / (31 * 24 * max_transmission_capacity)
  # Compute line utilization for October
  utilization_oct <- total_abs_oct / (30 * 24 * max_transmission_capacity)
  
  # Convert utilization results to data frames for saving
  utilization_rate_all_df <- as.data.frame(t(utilization_all))
  utilization_rate_sep_df <- as.data.frame(t(utilization_sep))
  utilization_rate_oct_df <- as.data.frame(t(utilization_oct))
  
  # Set column names using the line list for readability
  colnames(utilization_rate_all_df) <- line_list
  colnames(utilization_rate_sep_df) <- line_list
  colnames(utilization_rate_oct_df) <- line_list
  
  # Extracting the first and second rows, and transposing for September
  line_names_all <- colnames(utilization_rate_all_df)
  utilization_rates_all <- as.numeric(utilization_rate_all_df[1, ])
  new_df_all <- data.frame(Path = line_names_all, Rate = utilization_rates_all)
  
  # Extracting the first and second rows, and transposing for September
  line_names_sep <- colnames(utilization_rate_sep_df)
  utilization_rates_sep <- as.numeric(utilization_rate_sep_df[1, ])
  new_df_sep <- data.frame(Path = line_names_sep, Rate = utilization_rates_sep)
  
  # Extracting the first and second rows, and transposing for October
  line_names_oct <- colnames(utilization_rate_oct_df)
  utilization_rates_oct <- as.numeric(utilization_rate_oct_df[1, ])
  new_df_oct <- data.frame(Line = line_names_oct, Rate = utilization_rates_oct)
  
  # Save to CSV files
  write.csv(new_df_all, file.path(path, 'LineUtilizationRate_ABS_12Week.csv'), row.names = FALSE)
  write.csv(new_df_sep, file.path(path, 'LineUtilizationRate_ABS_09.csv'), row.names = FALSE)
  write.csv(new_df_oct, file.path(path, 'LineUtilizationRate_ABS_10.csv'), row.names = FALSE)
}


#################################
#################################
#################################
###Part2: Plot figure

rm(list=ls())

### Prerequisite packages
requiredPackages <- c('sf', 'ggplot2', 'ggpubr', 'ggmap', 'dplyr', 'viridis', 'hrbrthemes', 'tidyr', 'here', 'cowplot', 'gridExtra', 'RColorBrewer')     

for(package in requiredPackages){
  if(!require(package, character.only = TRUE)) 
    install.packages(package)
  library(package, character.only = TRUE)
}

# Set parent directory
parent_dir <- dirname(getwd())

# Path to the shapefile
shapefile_path <- file.path(getwd(), "China_map_shp", "NEGandNCG.shp")

# Read the shapefile
china_shape <- st_read(shapefile_path)

# Define coordinates for each region
NE_long_lat <- data.frame(
  zone = c('HL', 'IME',  'JL',  'LN',   'JB',   'SD'),
  lat =  c(47.5, 47.4,  43.83,  41.2,  39.58,  36.36),
  lon =  c(129, 120.8, 126.55, 122.5, 116.23, 118.17)
)

# Create paths for the scenarios
prioritymlt <- file.path(parent_dir, 'Results_ne_2021_PriorityMLT')
mlt <- file.path(parent_dir, 'Results_ne_2021_MLT')
spotmlt <- file.path(parent_dir, 'Results_ne_2021_SpotMLT')
flexiblespotmlt <- file.path(parent_dir, 'Results_ne_2021_FlexibleSpotMLT')

Results_path <- list(prioritymlt, mlt, spotmlt, flexiblespotmlt)


# Initialize variables to store global minimum and maximum
global_min <- Inf
global_max <- -Inf

# Iterate through all files to update the global minimum and maximum
for (path in Results_path) {
  temp_flow <- read.csv(file.path(path, 'FlowABS_sum_12Week.csv'))
  temp_flow <- temp_flow / 1000
  
  # Update the global minimum and maximum
  if (min(temp_flow) < global_min) {
    global_min <- min(temp_flow)
  }
  if (max(temp_flow) > global_max) {
    global_max <- max(temp_flow)
  }
}
# Ensure the global minimum is non-negative when applicable
global_min <- max(global_min, 0)

# Create an empty list to store the four plots
plot_list <- list()

for (path in Results_path){
  Path_text <- case_when(
    path == prioritymlt ~ 'prioritymlt',
    path == mlt ~ 'mlt',
    path == spotmlt ~ 'spotmlt',
    path == flexiblespotmlt ~ 'flexiblespotmlt'
  )
  
  Scenarios_title <- case_when(
    path == prioritymlt ~ 'PriorityMLT',
    path == mlt ~ 'MLT',
    path == spotmlt ~ 'SpotMLT',
    path == flexiblespotmlt ~ 'FlexibleSpotMLT'
  )
  
  # Read flow data
  temp_flow <- read.csv(file.path(path, 'FlowABS_sum_12Week.csv'))
  temp_flow <- temp_flow / 1000
  
  # Transform the dataframe to long format
  temp_flow_long <- temp_flow %>%
    pivot_longer(cols = everything(), names_to = "Path", values_to = "Total") %>%
    separate(col = Path, into = c("From", "To"), sep = "_to_")
  
  # Adjust flow directions
  temp_flow_long <- temp_flow_long %>%
    mutate(From = if_else(Total < 0, To, From),
           To = if_else(Total < 0, From, To),
           Total = abs(Total))
  
  # Assuming NE_long_lat is already loaded in your environment
  temp_flow_long <- temp_flow_long %>%
    left_join(NE_long_lat, by = c("From" = "zone")) %>%
    left_join(NE_long_lat, by = c("To" = "zone")) %>%
    rename(From_lat = lat.x,
           From_lon = lon.x,
           To_lat = lat.y,
           To_lon = lon.y,
           Net_trans_GWh = Total)
  
  
  ## Plotting: use global minimum and maximum to define the color legend
  temp_plot_long <- ggplot() +
    geom_sf(data = china_shape, fill = "transparent", color = "black", size = 0.5) +
    geom_segment(data = temp_flow_long, aes(x = From_lon, y = From_lat,
                                            xend = (To_lon + From_lon)/2, yend = (To_lat + From_lat)/2,
                                            color = Net_trans_GWh,
                                            size = Net_trans_GWh),
                 lineend = "round",
                 linejoin = "mitre",
                 alpha = 1) +
    geom_segment(data = temp_flow_long, aes(x = (To_lon + From_lon)/2, y = (To_lat + From_lat)/2,
                                            xend = To_lon, yend = To_lat,
                                            color = Net_trans_GWh,
                                            size = Net_trans_GWh),
                 lineend = "round",
                 linejoin = "mitre",
                 alpha = 1) +
    scale_color_viridis(discrete = FALSE, name = "GWh", limits = c(global_min, global_max)) +
    scale_size_continuous(range = c(0.5, 9), guide = FALSE) +  # Increase the contrast in line thickness
    coord_sf(xlim = c(114, 133.8), ylim = c(34, 51)) +
    theme_void() +
    labs(title = Scenarios_title) +
    theme(
      plot.title = element_text(size = 28, hjust = 0.01, vjust = -5),
      legend.title = element_text(size = 16),
      legend.text = element_text(size = 14) 
    ) +  # Set title font size
    geom_point(data = NE_long_lat, aes(x = lon, y = lat), color = "grey30", size = 10) +
    geom_text(data = NE_long_lat, aes(x = lon, y = lat, label = zone),
              color = "black", size = 10, family = "Arial", nudge_x = -1.2, nudge_y = 1.2) +
    theme(legend.position = c(0.80, 0.23)) +  # Place the legend near the lower-left corner
    guides(color = guide_colorbar(
      barwidth = 2.5,   # Increase legend bar width
      barheight = 9  # Increase legend bar length
    ))
  
  ## Assign and save the plot
  assign(paste('Flow', Path_text, sep = "_"), temp_plot_long)
  
  # Commenting out the code that saves individual scenario plots
  # ggsave(file.path(parent_dir, paste('Plot_TransmissionABS_all_', Path_text,'', '.jpeg', sep = '')),
  #        temp_plot_long, width = 7, height = 8, dpi = 500)
  
  plot_list[[length(plot_list) + 1]] <- temp_plot_long
  
}

# Arrange the plots in a 2x2 grid
combined_plot <- plot_grid(plotlist = plot_list, ncol = 2)

# Save the combined plot
ggsave(file.path('figure4.jpeg'), combined_plot, width = 16, height = 16, dpi = 700)