
function AggResults()

    total_cost = DataFrame()
    sumVar, sumNSE, sumStart = 0, 0, 0
    for count in 1:numweek
        cost_week = CSV.read(joinpath(resultpath, string(count), "cost_components.csv"), DataFrame)
        sumVar += first(cost_week[cost_week.Component .== "eVarCostGen", :Values])
        sumNSE += first(cost_week[cost_week.Component .== "eNSECosts", :Values])
        sumStart += first(cost_week[cost_week.Component .== "eStartCostUC", :Values])
    end
    total_cost.Component = ["eVarCostGen", "eNSECosts", "eStartCostUC"]
    total_cost.Values = [sumVar, sumNSE, sumStart]
    total_cost.Percentage = [sumVar / sum(total_cost.Values), sumNSE / sum(total_cost.Values), sumStart / sum(total_cost.Values)]
    CSV.write(joinpath(resultpath, "totalcost.csv"), total_cost)

    nse_total = DataFrame()
    nse_total.Week = 1:numweek
    for numzone in 1:first(size(reg_zone))
        maxmwnse, maxmwper, avermwnse, avermwper = [], [], [], []
        for count in 1:numweek

            nsefile = CSV.read(joinpath(resultpath, string(count), string("vNSE", numzone, ".csv")), DataFrame)

            select!(nsefile, Not(:Index))
            push!(maxmwnse, first(maximum.(eachrow(nsefile))))
            push!(avermwnse, first(mean.(eachrow(nsefile))))

            nse_percentage = nsefile ./ transpose(load_transition[count][:,numzone])
            push!(maxmwper, first(maximum.(eachrow(nse_percentage))))
            push!(avermwper, first(mean.(eachrow(nse_percentage))))

        end
        nse_total[!, string("Zone ", numzone, " Max NSE MW")] = maxmwnse
        # nse_total[!, string("Zone ", numzone, " Average NSE MW")] = avermwnse
        # nse_total[!, string("Zone ", numzone, " Max NSE %")] = maxmwper
        # nse_total[!, string("Zone ", numzone, " Average NSE %")] = avermwper
    end
    CSV.write(joinpath(resultpath, "nsesummary.csv"), nse_total)
    
    if scenario_name in ["demandresponse", "combinedr"]
        dr_total = DataFrame()
        dr_total.Week = 1:numweek
        for numzone in 1:first(size(reg_zone))
            maxmwnse, maxmwper, avermwnse, avermwper = [], [], [], []
            for count in 1:numweek

                nsefile = CSV.read(joinpath(resultpath, string(count), string("vNSE", numzone, ".csv")), DataFrame)

                select!(nsefile, Not(:Index))
                push!(maxmwnse, maximum.(nsefile[2, :]))
                push!(avermwnse, mean.(nsefile[2, :]))

                nse_percentage = nsefile ./ transpose(load_transition[count][:,numzone])
                push!(maxmwper, maximum.(nse_percentage[2, :]))
                push!(avermwper, mean.(nse_percentage[2, :]))

            end
            nse_total[!, string("Zone ", numzone, " Max NSE MW")] = maxmwnse
            nse_total[!, string("Zone ", numzone, " Average NSE MW")] = avermwnse
            nse_total[!, string("Zone ", numzone, " Max NSE %")] = maxmwper
            nse_total[!, string("Zone ", numzone, " Average NSE %")] = avermwper
        end
        CSV.write(joinpath(resultpath, "drsummary.csv"), dr_total)
    else
        nothing
    end
    

    # Initialize empty DataFrames to store results for wind, solar, and combined RES (renewable energy sources)
    fcur_wind = DataFrame()
    fcur_solar = DataFrame()
    fcur_RES = DataFrame()
    ftotal_RES = DataFrame()
    ftotal_RES_NEG = DataFrame()

    for i in 1:numweek
        file_path_wind = joinpath(resultpath, string(i), "curtailment_wind_weekly.csv")
        file_path_solar = joinpath(resultpath, string(i), "curtailment_solar_weekly.csv") 
        file_path_RES = joinpath(resultpath, string(i), "curtailment_RES_weekly.csv") 

        df_wind = CSV.read(file_path_wind, DataFrame)
        df_solar = CSV.read(file_path_solar, DataFrame)
        df_RES = CSV.read(file_path_RES, DataFrame)

        # Extract curtailment rates for wind, solar, and RES
        curtailment_rate_wind = df_wind[:, :Curtailment_rate]
        curtailment_rate_solar = df_solar[:, :Curtailment_rate]
        curtailment_rate_RES = df_RES[:, :Curtailment_rate]

        # Initialize "Region" column and total potential/cumulative curtailments on the first iteration
        if i == 1
                fcur_wind[:, :Region] = df_wind[:, 1]  # Assume the first column is the 'Region' information
                fcur_solar[:, :Region] = df_solar[:, 1]
                fcur_RES[:, :Region] = df_wind[:, 1]  # Same 'Region' column in wind, solar, and RES DataFrames
                ftotal_RES[:, :Region] = df_wind[:, 1] # Same 'Region' column
                ftotal_RES[:, :TotalPotentials]   = df_wind[:, :TotalPotentials] .+ df_solar[:, :TotalPotentials]
                ftotal_RES[:, :TotalCurtailments] = df_wind[:, :TotalCurtailments]
        else
                ftotal_RES[:, :TotalPotentials]   = ftotal_RES[:, :TotalPotentials]   .+ df_wind[:, :TotalPotentials] .+ df_solar[:, :TotalPotentials]
                ftotal_RES[:, :TotalCurtailments] = ftotal_RES[:, :TotalCurtailments] .+ df_wind[:, :TotalCurtailments] .+ df_solar[:, :TotalCurtailments]
        end

            # Add curtailment rate data for each week to the respective DataFrames
            fcur_wind[:, Symbol("Week$i")] = curtailment_rate_wind
            fcur_solar[:, Symbol("Week$i")] = curtailment_rate_solar
            fcur_RES[:, Symbol("Week$i")] = curtailment_rate_RES 
    end
    
    ftotal_RES[:, :Curtailment_rate] = ftotal_RES[:, :TotalCurtailments] ./ ftotal_RES[:, :TotalPotentials]
    push!(ftotal_RES, ("NEG", sum(ftotal_RES.TotalPotentials[1:4]),  sum(ftotal_RES.TotalCurtailments[1:4]), sum(ftotal_RES.TotalCurtailments[1:4])/sum(ftotal_RES.TotalPotentials[1:4]) ))

    # Write the resulting summary DataFrames to CSV
    CSV.write(joinpath(resultpath, "curtailmentsummary_wind.csv"), fcur_wind)
    CSV.write(joinpath(resultpath, "curtailmentsummary_solar.csv"), fcur_solar)
    CSV.write(joinpath(resultpath, "curtailmentsummary_RES.csv"), fcur_RES)
    CSV.write(joinpath(resultpath, "curtailmentsummary_RES_cumulative.csv"), ftotal_RES)



    flow_over_period = DataFrame()
    utilization = DataFrame()
    for count in 1:numweek
        if count == 1
            flow_over_period = CSV.read(joinpath(resultpath, string(count), "vFLOW_results.csv"), DataFrame)
            select!(flow_over_period, Not([:Index, :Path]))
            flow_over_period_pos = abs.(flow_over_period)
            utilization = flow_over_period_pos ./ network_fwd.Line_Max_Flow_MW   # Same: network_rvs
        else
            flow_tobesummed = CSV.read(joinpath(resultpath, string(count), "vFLOW_results.csv"), DataFrame)
            select!(flow_tobesummed, Not([:Index, :Path]))
            flow_over_period = flow_over_period .+ flow_tobesummed
            utilization = hcat(utilization, abs.(flow_tobesummed) ./ network_fwd.Line_Max_Flow_MW, makeunique = true) # Same: network_rvs
        end
    end
    flow_summary = DataFrame()
    flow_summary.Path = CSV.read(joinpath(resultpath, string(1), "vFLOW_results.csv"), DataFrame).Path
    flow_summary.Total = sum.(eachrow(flow_over_period)) / 1000
    utilization_summary = DataFrame()
    utilization_summary.Path = CSV.read(joinpath(resultpath, string(1), "vFLOW_results.csv"), DataFrame).Path
    utilization_summary.Rate = mean.(eachrow(utilization))
    CSV.write(joinpath(resultpath, "period_flow.csv"), flow_summary)
    CSV.write(joinpath(resultpath, "period_line_utilization.csv"), utilization_summary)

    weekly_renewable_share = []
    dispatch_over_period = DataFrame()
    for count in 1:numweek
        if count == 1
            dispatch_over_period = CSV.read(joinpath(dispatchpath, string(count), "dispatch_summary.csv"), DataFrame)
            region_names = dispatch_over_period.Region
            select!(dispatch_over_period, Not([:Region, :STOR]))
            dispatch_over_period = coalesce.(dispatch_over_period, 0.0)
            push!(weekly_renewable_share,
            (sum(dispatch_over_period.SOLAR) + sum(dispatch_over_period.WIND) + sum(dispatch_over_period.HYDRO))
            / sum(sum.(eachcol(dispatch_over_period))))
        else
            dispatch_tobesummed = CSV.read(joinpath(dispatchpath, string(count), "dispatch_summary.csv"), DataFrame)
            select!(dispatch_tobesummed, Not([:Region, :STOR]))
            dispatch_tobesummed = coalesce.(dispatch_tobesummed, 0.0)
            push!(weekly_renewable_share,
            (sum(dispatch_tobesummed.SOLAR) + sum(dispatch_tobesummed.WIND) + sum(dispatch_tobesummed.HYDRO))
            / sum(sum.(eachcol(dispatch_tobesummed))))
            dispatch_over_period = dispatch_over_period .+ dispatch_tobesummed
        end
    end
    push!(weekly_renewable_share,
    (sum(dispatch_over_period.SOLAR) + sum(dispatch_over_period.WIND) + sum(dispatch_over_period.HYDRO))
    / sum(sum.(eachcol(dispatch_over_period))))

    vre_share = DataFrame()
    week_series = collect(1:numweek)
    push!(week_series, numweek + 1)
    vre_share.Week = week_series
    vre_share.Share = weekly_renewable_share
    CSV.write(joinpath(resultpath, "renewable_share.csv"), vre_share)

    insertcols!(dispatch_over_period, 1, :Region => region_names)
    CSV.write(joinpath(resultpath, "period_dispatch.csv"), dispatch_over_period)

end
