# UCED-NEG: Unit Commitment and Economic Dispatch Model for Northeast China Grid

## 1. Overview

This repository contains the unit commitment and economic dispatch (UCED) model for the Northeast Power Grid  (ECG) of China for the study **"Resource Adequacy Under Institutional Constraints and the Low-Carbon Energy Transition in China"**. The model is written using [Julia](https://julialang.org/) and uses  [Gurobi](https://www.gurobi.com/)  as the optimization solver. Results are visualized using [R](https://www.r-project.org/) and [Python](https://www.python.org/). The model solves weekly optimization problems for the 12 weeks spanning August to October.

This repository is mainly structured into two components:

1. **2021 retrospective analysis (`uced-neg-2021`)**: Focused on historical data and scenarios.
2. **2030 forward-looking analysis (`uced-neg-2030`)**: Focused on future projections and scenarios.

In addition, **figures_for_paper** contains the figures displayed in the JEPO paper.

Contact Ming (m2wei at ucsd dot edu) if you run into any issues.

---

## 2. System Requirements

### Hardware

- **Operating System**: macOS or Windows.
- **Minimum Requirements**: 
  - 4 GB RAM
  - 1 GB disk space
  - Intel Core i5 or equivalent processor.

### Software

- **Julia**: Version 1.8.3
- **Gurobi**: Version 10.0.1 (requires a valid license)
- **Python**: Version 3.9 (for visualization and post-processing)
- **R**: Version 4.3.1 (for visualization and post-processing)

### Julia Dependencies

- JuMP=1.16.0
- DataFrames=1.3.6
- CSV=0.10.11
- Missings=1.1.0

### Python Dependencies

- pandas=1.5.3
- numpy=1.23.5
- gurobipy=10.0.2
- matplotlib=3.7.1
- geopandas=0.12.3
- plotly=5.14.0

### R Dependencies

- dplyr=1.1.4
- readr=2.1.4
- sf=1.0.16
- ggplot2=3.4.3
- ggpubr=0.6.0
- ggmap=3.0.2
- viridis=0.6.4
- hrbrthemes=0.8.0
- tidyr=1.3.0
- here=1.0.1
- cowplot=1.1.1
- gridExtra=2.3
- RColorBrewer=1.1.3

---

## 3. Installation Guide

1. Install Julia dependencies:

   ```julia
   using Pkg
   Pkg.add(["JuMP", "DataFrames", "CSV", "Missings", "Gurobi"])
   ```

2. Install Python dependencies:

   ```bash
   pip install pandas numpy gurobipy matplotlib geopandas plotly
   ```

3. Ensure you have a valid Gurobi license. Academic licenses can be obtained [here](https://www.gurobi.com/academia/academic-program-and-licenses/).

---

## 4. Running the Model

### Local Execution

1. Run the model:

   ```bash
   julia Run.jl
   ```

2. Outputs will be saved in the `Batch` directory, organized by scenario and week.

### Cloud Execution

1. Create a shell script adapted to your server environment.

2. Submit the job to the cluster, e.g.:

   ```bash
   sbatch Run_cluster.sh
   ```

3. Retrieve results using tools like FileZilla.

---

## 5. Data Description

- **Fuels_data**: Fuel cost and availability data.
- **Generators_data**: Information on generators, including:
  - Resource type (e.g., solar, wind, coal).
  - Capacity, ramping, and heat rate.
  - Fuel requirements and costs, etc.
- **Generators_variability**: Hourly variability of each generator.
- **Heat_time**: Heating and non-heating periods for each province.
- **Load_data**: Hourly demand data for four zones in the Northeast China Grid and two zones in the North China Grid.
- **Network_forward/Network_reverse**: Transmission network setup in both directions.
- **Transmission_MLT**: Hourly interprovincial/interregional transmission amount stipulated by Medium to Long-term (MLT) contracts.
- **Operating_reserve**: Reserve requirements for loads and VRE.
- **other_inputs**: Initial and final states of storage; reservoir's minimum level.

---

## 6. Script Description

- **Run.jl**: Main script to execute the model.
- **Paths.jl**: Defines input/output directories.
- **ReadFiles.jl**: Reads input data files.
- **SetCreation.jl**: Creates data sets for indexing.
- **EDUCModel.jl**: Core UCED model function.
- **RecordCSV.jl**: Saves main optimization outputs to CSV.
- **ProcessDispatch.jl**: Processes and records hourly dispatch results.
