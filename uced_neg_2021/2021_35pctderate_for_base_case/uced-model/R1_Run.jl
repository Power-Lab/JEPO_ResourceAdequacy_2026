using JuMP, DataFrames, CSV, Gurobi, Missings, Statistics

create_plot = false


# Global variables：targetyear, loadgrowth, weatheryear, scenario_name
global targetyear = ""
global loadgrowth = ""
global weatheryear = ""
global scenario_name = ""

# Initial `load_transition`, `genvar_transition`, `mlt_transition` 和 `solver_params`
global load_transition
global genvar_transition
global mlt_transition
global solver_params

# 定义运行模型的函数
function run_model(ty, lg, wy, sn)
    # 更新全局变量
    global targetyear = ty
    global loadgrowth = lg
    global weatheryear = wy
    global scenario_name = sn
    #global runname = string(targetyear, "_", scenario_name, "_", weatheryear)
    global runname = string(targetyear, "_", scenario_name)

    println("Running scenario with targetyear: ", runname)

    # 读取 solver 参数并赋值为全局变量
    global solver_params = CSV.read(joinpath(mainloc, "P0_solver_params.csv"), DataFrame)
    
    # 包含各模块文件
    include(joinpath(mainloc, "P1_Paths.jl"))
    include(joinpath(mainloc, "P2_ReadFiles.jl"))
    include(joinpath(mainloc, "P3_SetCreation.jl"))
    include(joinpath(mainloc, "R2_EDUCModel.jl"))
    include(joinpath(mainloc, "S1_RecordCSV.jl"))
    include(joinpath(mainloc, "S2_AggregateResults.jl"))
    include(joinpath(mainloc, "S3_ProcessDispatch.jl"))

    # 初始化 `load_transition`, `genvar_transition`, 和 `mlt_transition`
    global load_transition = load
    load_transition.Group = repeat(1:numweek, inner = hours_per_period)
    global load_transition = groupby(load_transition, :Group)

    global genvar_transition = genvar
    genvar_transition.Group = repeat(1:numweek, inner = hours_per_period)
    global genvar_transition = groupby(genvar_transition, :Group)

    global mlt_transition = mlt
    mlt_transition.Group = repeat(1:numweek, inner = hours_per_period)
    global mlt_transition = groupby(mlt_transition, :Group)

    # 调用模型和结果函数
    Base.invokelatest(EDUCModel)
    Base.invokelatest(AggResults)

    println("######################################################")
    println(" 🔧 Model solved successfully for ", targetyear, "! Ready to launch to Mars 🪐")
    println("######################################################")
end


##
# Define global directory and folder
global main_input_folder = "ne_2021_maininput"
global mainloc = @__DIR__

# Define parameters for each scenario combination 
ty_options = ["ne_2021"]
loadgrowth_options = [""]  # no load growth in 2021 case
weatheryear_options =[""] # no weather year in 2021 case
scenario_name_options = ["PriorityMLT", "MLT", "SpotMLT", "FlexibleSpotMLT" ]

# Run all scenario combinations
for ty in ty_options
    for lg in loadgrowth_options
        for wy in weatheryear_options
            for sn in scenario_name_options
                run_model(ty, lg, wy, sn)
            end
        end
    end
end



