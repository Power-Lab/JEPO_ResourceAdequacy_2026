# Clear the workspace
rm(list=ls())

# List of required packages
requiredPackages <- c('ggplot2', 'ggpubr', 'ggmap', 'dplyr', 'viridis', 'hrbrthemes', 'tidyr', 'here', 'cowplot', 'gridExtra')

# Install and load packages if not already installed
for(packages in requiredPackages) {
  if(!require(packages, character.only = TRUE)) install.packages(packages)
  library(packages, character.only = TRUE)
}

# Set the parent directory
parent_dir <- dirname(getwd())

# Resolve the directory where this script lives so outputs stay alongside it
get_script_dir <- function() {
  if (!is.null(sys.frames()[[1]]$ofile)) {
    return(dirname(normalizePath(sys.frames()[[1]]$ofile)))
  }
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub('^--file=', '', args[grep('^--file=', args)])
  if (length(file_arg) > 0) {
    return(dirname(normalizePath(file_arg[1])))
  }
  return(normalizePath('.'))
}
script_dir <- get_script_dir()

# Define paths for different scenarios
prioritymlt <- file.path(parent_dir, 'Results_ne_2021_PriorityMLT')
mlt <- file.path(parent_dir, 'Results_ne_2021_MLT')
spotmlt <- file.path(parent_dir, 'Results_ne_2021_SpotMLT')
flexiblespotmlt <- file.path(parent_dir, 'Results_ne_2021_FlexibleSpotMLT')

# List of result paths
Results_path <- list(prioritymlt, mlt, spotmlt, flexiblespotmlt)

# Process line utilization bar plot for each scenario
for (path in Results_path) {
  Path_text <- case_when(
    path == prioritymlt ~ 'prioritymlt',
    path == mlt ~ 'mlt',
    path == spotmlt ~ 'spotmlt',
    path == flexiblespotmlt ~ 'flexiblespotmlt'
  )
  
  print(paste("Processing:", path))
  print(paste("Assigned scenario label:", Path_text))
  
  # Check if the file exists before attempting to read
  file_path <- file.path(path, 'LineUtilizationRate_ABS_12Week.csv')
  if (file.exists(file_path)) {
    temp_ut <- read.csv(file_path)
    temp_ut <- temp_ut %>%
      mutate(Scenario = Path_text)
    assign(paste(Path_text, "line_ut", sep = '_'), temp_ut)
    print(paste("Dataframe created for:", Path_text))
  } else {
    print(paste("File not found:", file_path))
  }
}

# Combine dataframes and process for plotting
Line_ut <- rbind(prioritymlt_line_ut, mlt_line_ut, spotmlt_line_ut, flexiblespotmlt_line_ut) %>%
  mutate(Path = case_when(
    Path == 'HL_to_IME' ~ 'HL-IME',
    Path == 'HL_to_JL' ~ 'HL-JL',
    Path == 'IME_to_JL' ~ 'IME-JL',
    Path == 'IME_to_LN' ~ 'IME-LN',
    Path == 'JL_to_LN' ~ 'JL-LN',
    Path == 'IME_to_SD' ~ 'IME-SD',
    Path == 'LN_to_JB' ~ 'LN-JB'
  )) %>%
  mutate(Scenario = factor(Scenario, levels = c('prioritymlt', 'mlt', 'spotmlt', 'flexiblespotmlt')))

# Create the plot
temp_plot <- ggplot(data = Line_ut, aes(fill = Scenario, x = Path, y = Rate)) +
  geom_bar(position = "dodge", stat = "identity", alpha = 0.9, width = 0.7) +
  labs(
    title = '',
    x = NULL,
    y = "Transmission Path Utilization Rate",
    fill = ''
  ) +
  scale_fill_manual(
    breaks = c('prioritymlt', 'mlt', 'spotmlt', 'flexiblespotmlt'),
    values = c('palegreen4', 'sandybrown', 'lightblue', 'palevioletred'),
    labels = c('PriorityMLT', 'MLT', 'SpotMLT', 'FlexibleSpotMLT')
  ) +
  scale_y_continuous(
    labels = scales::percent_format(scale = 100),
    limits = c(0, 1)
  ) +
  theme(
    text = element_text(size = 14),
    title = element_text(hjust = 0),
    axis.ticks.x = element_blank(),
    axis.line.x = element_blank(),
    axis.title.x = element_text(hjust = .5),
    axis.title.y = element_text(hjust = .3),
    panel.grid.major.y = element_line(color = 'gray', size = .3),
    panel.grid.minor.y = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    panel.border = element_blank(),
    panel.background = element_blank(),
    legend.position = c(0.715, 0.96),
    legend.direction = 'horizontal',
    strip.text = element_text(face = "bold"),
    strip.background = element_blank(),
    plot.title = element_text(hjust = 0.5, face = 'bold', size = 18, color = 'black'),
    strip.placement = "outside"
  )

# Save the plot as a PDF file in the script directory
ggsave(file.path(script_dir, 'figure_SI2.pdf'), plot = temp_plot, width = 10, height = 4, dpi = 500)
