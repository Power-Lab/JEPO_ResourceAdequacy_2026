generators = CSV.read(joinpath(inputpath_main, "Generators_data.csv"), DataFrame)
demand = CSV.read(joinpath(inputpath_main, "Load_data" * loadgrowth * ".csv"), DataFrame)
network_fwd = CSV.read(joinpath(inputpath_main, "Network_forward.csv"), DataFrame)
network_rvs = CSV.read(joinpath(inputpath_main, "Network_reverse.csv"), DataFrame)
fuels = CSV.read(joinpath(inputpath_main, "Fuels_data.csv"), DataFrame)
mlt = CSV.read(joinpath(inputpath_main, "Transmission_MLT.csv"), DataFrame)
operatingres = CSV.read(joinpath(inputpath_main, "operating_reserve.csv"), DataFrame)
other_info = CSV.read(joinpath(inputpath_main, "other_inputs.csv"), DataFrame)
heattime = CSV.read(joinpath(inputpath_main, "Heat_time.csv"), DataFrame)

# NSE penalty inputs
nse_reduction = CSV.read(joinpath(inputpath_main, "nse_reduction_" * scenario_name * ".csv"), DataFrame)

# Variability/derate selection
if scenario_name ∉ ["FlexibleSpotMLT"]
    genvar = CSV.read(joinpath(inputpath_main, "Generators_variability_derate40%.csv"), DataFrame)
    println("some units are derated due to high coal cost and capped electricity price (40% derated)")
else
    genvar = CSV.read(joinpath(inputpath_main, "Generators_variability_derate15%.csv"), DataFrame)
    println("no electricity price cap, so 15% derated")
end

hours_per_period = Int(first(other_info[other_info.Parameter .== "hours_per_period", :Value]))

regdesc, netzones = [], []
for x in collect(1:length(unique(generators.region)))
    push!(regdesc, first(generators[generators.Zone .== x, :region]))
    push!(netzones, string("z", x))
end

reg_zone = DataFrame()
reg_zone.Region_description = regdesc
reg_zone.Network_zones = netzones

region_names = reg_zone.Region_description

path_names = network_fwd.transmission_path_name

load_names = Array{String, 1}(undef, length(region_names))
for regnum in 1:length(region_names)
    load_names[regnum] = string("Load_MW_z", regnum)
end
load = select(demand, load_names)

heattime = select(heattime, r"^Heat_time_z")

numweek = Int(first(size(load)) / hours_per_period)

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

# NSE priority cost ratio
NE_nonserved_reduction = first(nse_reduction[nse_reduction.Parameter .== "NE_nonserved_reduction", :Value])