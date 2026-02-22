using JuMP, DataFrames, CSV, Gurobi, Missings, Statistics

create_plot = false

# targetyear, loadgrowth, weatheryear, scenario_name
global targetyear = ""
global loadgrowth = ""
global deraterate = ""
global weatheryear = ""
global scenario_name = ""

# `load_transition`, `genvar_transition`, `mlt_transition` 和 `solver_params`
global load_transition
global genvar_transition
global mlt_transition
global solver_params

# 
function run_model(ty, lg, dp, wy, sn)
    global targetyear = ty
    global loadgrowth = lg
    global weatheryear = wy
    global deratepercent = dp
    global scenario_name = sn
    global runname = string(targetyear, "_", scenario_name, "_",lg, "_", dp, "_", weatheryear)
    println("Running scenario with targetyear: ", runname)

    global solver_params = CSV.read(joinpath(mainloc, "P0_solver_params.csv"), DataFrame)
    
    # 
    include(joinpath(mainloc, "P1_Paths.jl"))
    include(joinpath(mainloc, "P2_ReadFiles.jl"))
    include(joinpath(mainloc, "P3_SetCreation.jl"))
    include(joinpath(mainloc, "R2_EDUCModel.jl"))
    include(joinpath(mainloc, "S1_RecordCSV.jl"))
    include(joinpath(mainloc, "S2_AggregateResults.jl"))
    include(joinpath(mainloc, "S3_ProcessDispatch.jl"))


=    # Initialize `load_transition`, `genvar_transition`, and `mlt_transition` with missing values handled
    global load_transition = load
    load_transition.Group = repeat(1:numweek, inner = hours_per_period)
    load_transition = coalesce.(load_transition, 0)
    global load_transition = groupby(load_transition, :Group)

    global genvar_transition = genvar
    genvar_transition.Group = repeat(1:numweek, inner = hours_per_period)
    genvar_transition = coalesce.(genvar_transition, 0)
    global genvar_transition = groupby(genvar_transition, :Group)

    global mlt_transition = mlt
    mlt_transition.Group = repeat(1:numweek, inner = hours_per_period)
    mlt_transition = coalesce.(mlt_transition, 0)
    global mlt_transition = groupby(mlt_transition, :Group)

    #
    Base.invokelatest(EDUCModel)
    Base.invokelatest(AggResults)

    println("######################################################")
    println(" 🔧 Model solved successfully for ", targetyear, "! Ready to launch to Mars 🪐")
    println("######################################################")
end


##
global main_input_folder = "ne_203007_maininput"
global mainloc = @__DIR__

ty_options = ["ne_203007"]
loadgrowth_options = [ "growth1","growth2","growth3"] 
deratepercent_options = ["derate5pct","derate7.5pct","derate10pct"] 
weatheryear_options = ["weather202207", "weather201407"]
scenario_name_options = ["PriorityMLT", "MLT", "SpotMLT" ]

for ty in ty_options
    for lg in loadgrowth_options
        for dp in deratepercent_options
            for wy in weatheryear_options
                for sn in scenario_name_options
                    run_model(ty, lg, dp, wy, sn)
                end
            end
        end
    end
end