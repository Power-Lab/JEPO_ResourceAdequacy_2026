# function RecordCSV(unitc, flowdec, flowpos, flowneg, flowabs, unmetdec, stres, allcap, genvar, count)
function RecordCSV(unitc, flowfwd, flowrvs, flowcombine, unmetdec, allcap, genvar, count)
    

    for var in unitc
        data = DataFrame(value.(var).data, :auto)
        insertcols!(data, 1, :Index => first(axes(value.(var))))
        insertcols!(data, 2, :Zone => generators.Zone[first(axes(value.(var)))])
        insertcols!(data, 3, :Region => generators.region[first(axes(value.(var)))])
        insertcols!(data, 4, :Resource => generators.technology[first(axes(value.(var)))])

        varname = first(split(name(var[first(first(axes(value.(var)))), 1]), "["))
        CSV.write(joinpath(resultpath, string(count), string(varname, "_results.csv")), data)
    end


    flowfwd_data = DataFrame(value.(flowfwd).data, :auto)
    insertcols!(flowfwd_data, 1, :Index => first(axes(value.(flowfwd))))
    insertcols!(flowfwd_data, 2, :Path => network_fwd.transmission_path_name[flowfwd_data.Index])
    CSV.write(joinpath(resultpath, string(count), "vFLOWFWD_results.csv"), flowfwd_data)

    flowrvs_data = DataFrame(value.(flowrvs).data, :auto)
    insertcols!(flowrvs_data, 1, :Index => first(axes(value.(flowrvs))))
    insertcols!(flowrvs_data, 2, :Path => network_fwd.transmission_path_name[flowrvs_data.Index])
    CSV.write(joinpath(resultpath, string(count), "vFLOWRVS_results.csv"), flowrvs_data)

    flowcombine_data = DataFrame(value.(flowcombine).data, :auto)
    insertcols!(flowcombine_data, 1, :Index => first(axes(value.(flowcombine))))
    insertcols!(flowcombine_data, 2, :Path => network_fwd.transmission_path_name[flowcombine_data.Index])
    CSV.write(joinpath(resultpath, string(count), "vFLOW_results.csv"), flowcombine_data)
 
    # flowdata_abs = DataFrame(value.(flowabs).data, :auto)
    # insertcols!(flowdata_abs, 1, :Index => first(axes(value.(flowabs))))
    # insertcols!(flowdata_abs, 2, :Path => network.transmission_path_name[flowdata_abs.Index])
    # CSV.write(joinpath(resultpath, string(count), "vFLOWABS_results.csv"), flowdata_abs)

    for row in 1:first(size(unmetdec))
        data = DataFrame(value.(unmetdec).data[row,:,:], :auto)
        insertcols!(data, 1, :Index => first(axes(value.(unmetdec)[row,:,:])))
        CSV.write(joinpath(resultpath, string(count), string("vNSE", row, ".csv")), data)
    end

    # for var in stres
    #     data = DataFrame(value.(var).data, :auto)
    #     insertcols!(data, 1, :Index => first(axes(value.(var))))
    #     insertcols!(data, 2, :Zone => generators.Zone[first(axes(value.(var)))])
    #     insertcols!(data, 3, :Region => generators.region[first(axes(value.(var)))])
    #     insertcols!(data, 4, :Resource => generators.technology[first(axes(value.(var)))])

    #     varname = first(split(name(var[first(first(axes(value.(var)))), 1]), "["))
    #     CSV.write(joinpath(resultpath, string(count), string(varname, "_results.csv")), data)
    # end

    allcap_data = DataFrame()
    allcap_data.R_ID = first(axes(value.(allcap)))
    allcap_data.Zone = generators.Zone[allcap_data.R_ID]
    allcap_data.Region = generators.region[allcap_data.R_ID]
    allcap_data.Resource = generators.technology[allcap_data.R_ID]
    allcap_data.OptValues = value.(allcap).data

    # NE China now doesn't consider CCS，Biopower, Geothermal, and other generators.
    colnames = [:R_ID, :STOR, :SOLAR, :COAL, :WIND, :GAS, :HYDRO, :NUCLEAR, :NONDISP] # Create common column names
    #colnames = [:R_ID, :STOR, :SOLAR, :BIOPOWER, :NONCCS_COAL, :CCS_COAL, :GEOTHERMAL, :WIND, :NONCCS_GAS, :CCS_GAS, :HYDRO, :NUCLEAR, :OTHER] # Create common column names

    allcap_res = innerjoin(allcap_data, generators[!, colnames], on = :R_ID) # Add Resource, region and label information from generators.csv (merge on R_ID)

    # Calculate CO2 emission amount
    dispatch_result = CSV.read(joinpath(resultpath, string(count), "vGENDISPATCH_results.csv"), DataFrame)
    start_result = CSV.read(joinpath(resultpath, string(count), "vSTARTUC_results.csv"), DataFrame)

    sort!(dispatch_result, :Index)
    sorted_dispatch = copy(dispatch_result)
    dispatch_renew = dispatch_result[generators[generators.RENEW .== 1, :R_ID],:]

    co2_start = CO2_Per_Start[start_result.Index]
    capsize = generators.Cap_Size[start_result.Index]

    select!(dispatch_result, Not([:Index,:Zone,:Region,:Resource]))
    select!(start_result, Not([:Index,:Zone,:Region,:Resource]))
    select!(dispatch_renew, Not([:Index,:Zone,:Region,:Resource]))

    co2_amount = sum((sum.(eachcol(CO2_Rate .* dispatch_result)) + sum.(eachcol(co2_start .* (capsize .* start_result)))) .* sample_weight)
    renew_share = sum(sum.(eachcol(dispatch_renew)) .* sample_weight) / sum(sum.(eachcol(dispatch_result)) .* sample_weight)

    environment = DataFrame()
    environment.CO2 = [co2_amount]
    # environment.Renew_Share = [renew_share]
    CSV.write(joinpath(resultpath, string(count), "environment.csv"), environment)

    select!(sorted_dispatch, Not([:Index, :Zone, :Region, :Resource]))
    sort!(allcap_res, [:R_ID])

    # final_curtailment = DataFrame()
    # # for agn in [:SOLAR, :WIND]
    # currate = []
    # for rname in region_names
    #     finalcap = allcap_res[(allcap_res.Region .== rname) .& (allcap_res.NONDISP .== 1) .& (allcap_res.OptValues .> 0), [:R_ID, :OptValues]]
    #     if first(size(finalcap)) != 0
    #         potentials = finalcap.OptValues' .* genvar[:, finalcap.R_ID]
    #         subdis = Matrix(sorted_dispatch[finalcap.R_ID, :])'
    #         weighted_cur = ((potentials .- subdis) ./ potentials) .* sample_weight
    #         for col in eachcol(weighted_cur) replace!(col, NaN => 0) end
    #         push!(currate, mean(sum.(eachcol(weighted_cur)) / sum(sample_weight)))
    #     else
    #         push!(currate, missing)
    #     end
    # end
    # final_curtailment.VRE = currate
    # # end
    # insertcols!(final_curtailment, 1, :Region => region_names)
    # CSV.write(joinpath(resultpath, string(count), "final_curtailment.csv"), final_curtailment)



        ## Record Curtailment: Weekly, Wind
        # weekly curtailment = (sum(hourly potentials) - sum(hourly dispatch))/ sum(hourly_potentials)
        final_curtailment_wind = DataFrame(Region = region_names)
        total_potentials = []  # 初始化一个空数组来存储每个地区的潜在总发电量。
        total_actuals = []  # 初始化一个空数组来存储每个地区的实际总发电量。
        total_curtailments = []  # 初始化一个空数组来存储每个地区的限制率。
        total_curtailmentrate = [] 

        for rname in region_names
            finalcap = allcap_res[(allcap_res.Region .== rname) .& (allcap_res.Resource .== "onshore_wind_turbine") .& (allcap_res.OptValues .> 0), [:R_ID, :OptValues]]
            
            if first(size(finalcap)) != 0
                potentials = finalcap.OptValues' .* genvar[:, finalcap.R_ID]
                for col in eachcol(potentials) replace!(col, NaN => 0) end
                potentials_sum = sum.(eachcol(potentials))
                push!(total_potentials, potentials_sum[1])  # 存储每个地区的潜在总发电量
                
                subdis = Matrix(sorted_dispatch[finalcap.R_ID, :])'
                for col in eachcol(subdis) replace!(col, NaN => 0) end
                subdis_sum = sum.(eachcol(subdis))
                push!(total_actuals, subdis_sum[1])  # 存储每个地区的实际总发电量
                
                curtailments_sum = potentials_sum - subdis_sum
                currate_temp = curtailments_sum/potentials_sum
                # 检查潜在发电量是否全为零
                if all(potentials_sum .== 0)
                    push!(total_curtailments, missing)  # 如果潜在发电量全为零，则无法计算限制率，使用missing标记。
                    push!(total_curtailmentrate, missing)  # 如果潜在发电量全为零，则无法计算限制率，使用missing标记。
                else
                    push!(total_curtailments, curtailments_sum[1])
                    push!(total_curtailmentrate, currate_temp[1])
                end
            else
                push!(total_potentials, 0)  # 无风力发电机的地区潜在总发电量为0
                push!(total_actuals, 0)  # 无风力发电机的地区实际总发电量为0
                push!(total_curtailments, missing)  # 如果没有风力发电机，也使用missing标记。
                push!(total_curtailmentrate, missing)  # 如果没有风力发电机，也使用missing标记。
            end 
        end
        
        final_curtailment_wind.TotalPotentials = total_potentials  # 添加潜在总发电量列
        final_curtailment_wind.TotalActuals = total_actuals  # 添加实际总发电量列
        final_curtailment_wind.TotalCurtailments = total_curtailments
        final_curtailment_wind.Curtailment_rate = total_curtailmentrate
        CSV.write(joinpath(resultpath, string(count), "curtailment_wind_weekly.csv"), final_curtailment_wind)
    

        ## Record Curtailment: Weekly, Solar
        final_curtailment_solar = DataFrame(Region = region_names)
        total_potentials = []  # 初始化一个空数组来存储每个地区的潜在总发电量。
        total_actuals = []  # 初始化一个空数组来存储每个地区的实际总发电量。
        total_curtailments = []  # 初始化一个空数组来存储每个地区的限制率。
        total_curtailmentrate = [] 

        for rname in region_names
            finalcap = allcap_res[(allcap_res.Region .== rname) .& (allcap_res.Resource .== "solar_photovoltaic") .& (allcap_res.OptValues .> 0), [:R_ID, :OptValues]]
            
            if first(size(finalcap)) != 0
                potentials = finalcap.OptValues' .* genvar[:, finalcap.R_ID]
                for col in eachcol(potentials) replace!(col, NaN => 0) end
                potentials_sum = sum.(eachcol(potentials))
                push!(total_potentials, potentials_sum[1])  # 存储每个地区的潜在总发电量
                
                subdis = Matrix(sorted_dispatch[finalcap.R_ID, :])'
                for col in eachcol(subdis) replace!(col, NaN => 0) end
                subdis_sum = sum.(eachcol(subdis))
                push!(total_actuals, subdis_sum[1])  # 存储每个地区的实际总发电量
                
                curtailments_sum = potentials_sum - subdis_sum
                currate_temp = curtailments_sum/potentials_sum
                # 检查潜在发电量是否全为零
                if all(potentials_sum .== 0)
                    push!(total_curtailments, missing)  # 如果潜在发电量全为零，则无法计算限制率，使用missing标记。
                    push!(total_curtailmentrate, missing)  # 如果潜在发电量全为零，则无法计算限制率，使用missing标记。
                else
                    push!(total_curtailments, curtailments_sum[1])
                    push!(total_curtailmentrate, currate_temp[1])
                end
            else
                push!(total_potentials, 0)  # 无风力发电机的地区潜在总发电量为0
                push!(total_actuals, 0)  # 无风力发电机的地区实际总发电量为0
                push!(total_curtailments, missing)  # 如果没有风力发电机，也使用missing标记。
                push!(total_curtailmentrate, missing)  # 如果没有风力发电机，也使用missing标记。
            end 
        end
        
        final_curtailment_solar.TotalPotentials = total_potentials  # 添加潜在总发电量列
        final_curtailment_solar.TotalActuals = total_actuals  # 添加实际总发电量列
        final_curtailment_solar.TotalCurtailments = total_curtailments
        final_curtailment_solar.Curtailment_rate = total_curtailmentrate
        CSV.write(joinpath(resultpath, string(count), "curtailment_solar_weekly.csv"), final_curtailment_solar)
   

        ## Record Curtailment: Weekly, RES (wind+solar)
        df_solar = CSV.read(joinpath(resultpath, string(count), "curtailment_solar_weekly.csv"), DataFrame)
        df_wind = CSV.read(joinpath(resultpath, string(count), "curtailment_wind_weekly.csv"), DataFrame)
        
        # 创建一个与 df_solar 结构相同的空 DataFrame，用于存储总的可再生能源（风能+太阳能）数据
        df_RES = similar(df_solar)
        df_RES[:, 1] = df_solar[:, 1]
        
        # 对第 2 到第 4 列（实际可再生能源数据列）进行逐元素加和
        for col in 2:4
            df_RES[:, col] .= coalesce.(df_solar[:, col], 0) .+ coalesce.(df_wind[:, col], 0)
        end
        
        # 计算弃风/弃光率：第 5 列 = 第 4 列的弃风量 / 第 2 列的总潜力
        df_RES[:, 5] .= df_RES[:, 4] ./ df_RES[:, 2]
        
        # 保存计算结果到 CSV 文件
        CSV.write(joinpath(resultpath, string(count), "curtailment_RES_weekly.csv"), df_RES)


        ## Record Curtailment: Hourly, Wind
        num_cols = hours_per_period
        hourly_curtailment_wind = DataFrame()
        column_names = ["Hour_$i" for i in 1:num_cols]
        for col_name in column_names
            hourly_curtailment_wind[!, col_name] = Any[]
        end
        hourly_curtailment_wind = convert.(Union{Float64, Missing}, hourly_curtailment_wind)


        for rname in region_names
            finalcap = allcap_res[(allcap_res.Region .== rname) .& (allcap_res.Resource .== "onshore_wind_turbine") .& (allcap_res.OptValues .> 0), [:R_ID, :OptValues]]
            if first(size(finalcap)) != 0
                potentials = finalcap.OptValues' .* genvar[:, finalcap.R_ID]
                subdis = Matrix(sorted_dispatch[finalcap.R_ID, :])'
                weighted_cur = ((potentials .- subdis))
                for col in eachcol(weighted_cur) replace!(col, NaN => 0) end
                push!(hourly_curtailment_wind,  weighted_cur[:,1])
            else
                push!(hourly_curtailment_wind, fill(missing, hours_per_period))
            end 
        end

        insertcols!(hourly_curtailment_wind, 1, :Region => region_names)
        CSV.write(joinpath(resultpath, string(count), "curtailment_wind_hourly.csv"), hourly_curtailment_wind)
        
        ## Record Curtailment: Hourly, Solar
            num_cols = hours_per_period
            hourly_curtailment_solar = DataFrame()
            column_names = ["Hour_$i" for i in 1:num_cols]
            for col_name in column_names
                hourly_curtailment_solar[!, col_name] = Any[]
            end
            hourly_curtailment_solar = convert.(Union{Float64, Missing}, hourly_curtailment_solar)

        
            for rname in region_names
                finalcap = allcap_res[(allcap_res.Region .== rname) .& (allcap_res.Resource .== "solar_photovoltaic") .& (allcap_res.NONDISP .== 1) .& (allcap_res.OptValues .> 0), [:R_ID, :OptValues]]
                if first(size(finalcap)) != 0
                    potentials = finalcap.OptValues' .* genvar[:, finalcap.R_ID]
                    subdis = Matrix(sorted_dispatch[finalcap.R_ID, :])'
                    weighted_cur = ((potentials .- subdis))
                    for col in eachcol(weighted_cur) replace!(col, NaN => 0) end
                    push!(hourly_curtailment_solar,  weighted_cur[:,1])
                else
                    push!(hourly_curtailment_solar, fill(missing, hours_per_period))
                end 
            end

            insertcols!(hourly_curtailment_solar, 1, :Region => region_names)
            CSV.write(joinpath(resultpath, string(count), "curtailment_solar_hourly.csv"), hourly_curtailment_solar)
   

end
