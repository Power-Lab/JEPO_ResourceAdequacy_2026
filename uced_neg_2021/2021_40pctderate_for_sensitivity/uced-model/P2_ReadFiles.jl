# Read path for reading generator information, demand profile, calculation index, network and operating reserve fractions 
generators = CSV.read(joinpath(inputpath_main, "Generators_data.csv"), DataFrame) # Reading generator data and create a data frame
# demand = CSV.read(joinpath(inputpath_main, "Load_data.csv"), DataFrame) # Reading demand data and create a data frame
demand = CSV.read(joinpath(inputpath_main, "Load_data" * loadgrowth * ".csv"), DataFrame)
network_fwd = CSV.read(joinpath(inputpath_main, "Network_forward.csv"), DataFrame) # Reading forward network data and create a data frame
network_rvs = CSV.read(joinpath(inputpath_main, "Network_reverse.csv"), DataFrame) # Reading reserved network data and create a data frame (same line, reverse direction)
fuels = CSV.read(joinpath(inputpath_main, "Fuels_data.csv"), DataFrame) # Reading fuels data and create a data frame
mlt = CSV.read(joinpath(inputpath_main, "Transmission_MLT.csv"), DataFrame) #Get interprovincial MLT contract (12 weeks * 168 h/wk = 2016 rows)
operatingres = CSV.read(joinpath(inputpath_main, "operating_reserve.csv"), DataFrame) # Read operating reserve fractions
other_info = CSV.read(joinpath(inputpath_main, "other_inputs.csv"), DataFrame) # Get other info from PowerGenome repository
heattime = CSV.read(joinpath(inputpath_main, "Heat_time.csv"), DataFrame)

# Read path for scenario nse pena1ty price: prioritized penalty for NCG (cNSE of NCG > cNSE of NEG)
nse_reduction = CSV.read(joinpath(inputpath_main, "nse_reduction_" * scenario_name * ".csv"), DataFrame) # Get other info from PowerGenome repository

# Read path for scenarios with capped electricity price （scenario "FlexibleSpotMLT"); capped electicity price means derated generators
if scenario_name ∉ ["FlexibleSpotMLT"]    # No "Flexible" in scenario name means no electricity price cap and no derated units.
    genvar = CSV.read(joinpath(inputpath_main, "Generators_variability_derate40%.csv"), DataFrame) # Reading generator variability data and create a data frame
    println("some units are derated due to high coal cost and capped electricity price (40% derated)")
else
    genvar = CSV.read(joinpath(inputpath_main, "Generators_variability_derate15%.csv"), DataFrame) # Reading generator variability data and create a data frame
    println("no electricity price cap, so 15% derated")
end

hours_per_period = Int(first(other_info[other_info.Parameter .== "hours_per_period", :Value])) # Reading hours per period data

regdesc, netzones = [], []
for x in collect(1:length(unique(generators.region)))
    push!(regdesc, first(generators[generators.Zone .== x, :region]))
    push!(netzones, string("z", x))
end

reg_zone = DataFrame()
reg_zone.Region_description = regdesc
reg_zone.Network_zones = netzones

region_names = reg_zone.Region_description

path_names = network_fwd.transmission_path_name #array that contains path name; Same: path_names = network_rvs.transmission_path_name #array that contains path name

# Get a clearer version of demand data frame and use it in the optimization
load_names = Array{String, 1}(undef, length(region_names))
for regnum in 1:length(region_names)
    load_names[regnum] = string("Load_MW_z", regnum)
end
load = select(demand, load_names)

# Get a clearer version of heat time data frame and use it in the optimization
heattime = select(heattime, r"^Heat_time_z")

numweek = Int(first(size(load)) / hours_per_period) # Number of weeks in the modeling horizon

# Set weight for each week if running annual model, here is 1 for all time
sample_weight = repeat(1:1, hours_per_period)

initfinalstate = first(other_info[other_info.Parameter .== "initfinalstate", :Value])
minreservoirlevel = first(other_info[other_info.Parameter .== "reservoirminlevel", :Value])

fuelnames = names(fuels)[2:end]
fuels = select(fuels, Not(:Time_Index))

co2_content = DataFrame(Matrix(fuels[1:1, :])', :auto)
rename!(co2_content, :x1 => :CO2_content_tons_per_MMBtu)
insertcols!(co2_content, 1, :Fuel => fuelnames)

fuel_cost = DataFrame(Matrix(fuels[2:end, :])', :auto)
insertcols!(fuel_cost, 1, :Fuel => fuelnames)

Var_Cost = zeros(first(size(generators)), first(size(load)))
CO2_Rate = zeros(first(size(generators)))
Start_Cost = zeros(first(size(generators)), first(size(load)))
CO2_Per_Start = zeros(first(size(generators)))

for g in 1:first(size(generators))
    Var_Cost[g,:] = Array(generators.Var_OM_Cost_per_MWh[g] .+ fuel_cost[fuel_cost.Fuel .== generators.Fuel[g], 2:end] .* generators.Heat_Rate_MMBTU_per_MWh[g])
    CO2_Rate[g] = first(co2_content[co2_content.Fuel .== generators.Fuel[g], :CO2_content_tons_per_MMBtu]) * generators.Heat_Rate_MMBTU_per_MWh[g]
    Start_Cost[g,:] = Array(generators.Start_Cost_per_MW[g] .+ fuel_cost[fuel_cost.Fuel .== generators.Fuel[g], 2:end] .* generators.Start_Fuel_MMBTU_per_MW[g])
    # Start_Cost[g,:] .= 0
    CO2_Per_Start[g] = first(co2_content[co2_content.Fuel .== generators.Fuel[g], :CO2_content_tons_per_MMBtu]) * generators.Start_Fuel_MMBTU_per_MW[g]
end

SDcont = first(other_info[other_info.Parameter .== "contingency_for_SD", :Value])
JBcont = first(other_info[other_info.Parameter .== "contingency_for_JB", :Value])

# "Priority" means NSE cost in NC grid is more expensive than that in NE grid
NE_nonserved_reduction = first(nse_reduction[nse_reduction.Parameter .== "NE_nonserved_reduction", :Value])