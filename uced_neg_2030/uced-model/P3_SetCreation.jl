
# Set of generators of differnt technologies
setWINDSOLAR = generators[(generators.SOLAR .== 1) .| (generators.WIND .== 1), :R_ID]
setHYDRO = generators[(generators.HYDRO .== 1), :R_ID]
setUC = generators[(generators.COAL .== 1) .| (generators.GAS .== 1) .| (generators.NUCLEAR .== 1), :R_ID]
setSTOR = generators[(generators.STOR .== 1), :R_ID] 
setCHP = generators[generators.technology .== "cogen_conventional_steam_coal", :R_ID] 
setGEN = union(setWINDSOLAR,setHYDRO,setUC,setSTOR) 

# setTIME
setTIME = collect(1:hours_per_period)
temp_segment = collect(skipmissing(demand.Demand_segment)) 

setSEGMENT = []
for i in 1:first(size(temp_segment))
    push!(setSEGMENT, Int(temp_segment[i]))
end

setZONE = unique(generators.Zone) # Set of zones
int_generators = filter(row -> row.region != "SD" && row.region != "JB", generators)
setIntZONE = unique(int_generators.Zone)
println("setIntZone includes ", setIntZONE)


setLINEFWD = collect(1:first(size(network_fwd)))
setLINERVS = collect(1:first(size(network_rvs))) 
setLINE = setLINEFWD 

SD_znumber = first(reg_zone[reg_zone.Region_description .== "SD", :Network_zones])
JB_znumber = first(reg_zone[reg_zone.Region_description .== "JB", :Network_zones])
println("zone number of SD is ", SD_znumber)
println("zone number of JB is ", JB_znumber)

# Select Network_Lines from network_fwd and network_rvs DataFrame (for SD and JB, i.e., external zone(s))
setSDLINEFWD = network_fwd[(network_fwd[!, Symbol(SD_znumber)] .== -1), :Network_Lines]
setSDLINERVS = network_rvs[(network_rvs[!, Symbol(SD_znumber)] .== 1), :Network_Lines]
setJBLINEFWD = network_fwd[(network_fwd[!, Symbol(JB_znumber)] .== -1), :Network_Lines]
setJBLINERVS = network_rvs[(network_rvs[!, Symbol(JB_znumber)] .== 1), :Network_Lines]

setExtLINE = vcat(setSDLINEFWD, setJBLINEFWD)
setIntLINE = setdiff(setLINEFWD, setExtLINE) 
println("setIntLINE is ", setIntLINE)
println("setExtLINE is ", setExtLINE)
println("line number of SD (forward) is ", setSDLINEFWD)  
println("line number of SD (reverse) is ",setSDLINERVS)

setSTARTS = [1]
setINTERIORS = setdiff(setTIME, setSTARTS)

contn1 = []
for z in setZONE
    if string("z", z) != SD_znumber && string("z", z) != JB_znumber
        maxuc = maximum(generators[intersect(setUC, generators[generators.Zone .== z, :R_ID]), :Cap_Size])
        maxline = maximum(network_fwd[(network_fwd[!, string("z", z)] .== 1) .| (network_fwd[!, string("z", z)] .== -1), :Max_AC_Cap])
        push!(contn1, maximum([maxuc, maxline]))
    elseif string("z", z) == SD_znumber
        push!(contn1, SDcont) 
    elseif string("z", z) == JB_znumber
        push!(contn1, JBcont) 
    else
        nothing
    end
end
println("contingency requirements (N-1-1) for each zone: ", contn1)

# Reading non-served energy data and create a data frame
nse = DataFrame(Segment = collect(skipmissing(demand.Demand_segment)),
                NSE_Cost = collect(skipmissing(demand.Cost_of_demand_curtailment_perMW)) * first(demand.Voll),
                NSE_Max = collect(skipmissing(demand.Max_demand_curtailment)))


# If multiple segments, use the codes below
nse_final = DataFrame()
for zone in setZONE
    nse_zone = copy(nse)
    insertcols!(nse_zone, 1, :Zone => fill(zone, nrow(nse_zone)))
    append!(nse_final, nse_zone)
end
nse = nse_final

# "Priority" means NSE cost in NC grid is more expensive than that in NE grid
if scenario_name in ["PriorityMLT", "PrioritySpot"]
    nse.NSE_Cost = nse.NSE_Cost
    nse[nse.Zone .== parse(Int64, string(SD_znumber[end])), :NSE_Cost] = nse[nse.Zone .== parse(Int64, string(SD_znumber[end])), :NSE_Cost] * NE_nonserved_reduction
    nse[nse.Zone .== parse(Int64, string(JB_znumber[end])), :NSE_Cost] = nse[nse.Zone .== parse(Int64, string(JB_znumber[end])), :NSE_Cost] * NE_nonserved_reduction
else
    nothing
end

NEG_NSEcost = nse.NSE_Cost
println("NEG: NSE penalty is ", NEG_NSEcost)
SD_NSEcost = nse[nse.Zone .== parse(Int64, string(SD_znumber[end])), :NSE_Cost]
println("SD and JB: NSE penalty is ", SD_NSEcost)
println(nse)