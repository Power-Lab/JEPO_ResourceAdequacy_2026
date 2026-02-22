
function EDUCModel()
    for (count, (load, genvar, mlt)) in enumerate(zip(load_transition, genvar_transition, mlt_transition))

        # Initialize solver
        EDUC_Model = Model(optimizer_with_attributes(Gurobi.Optimizer, "NonConvex" => 2))

        for paramrow in eachrow(solver_params)
            if paramrow.Type == "Integer"
                set_optimizer_attribute(EDUC_Model, "$(paramrow.Parameter)", Int(paramrow.Value))
            else
                set_optimizer_attribute(EDUC_Model, "$(paramrow.Parameter)", paramrow.Value)
            end
        end

        # VARIABLES
        # Unit commitment
        @variable(EDUC_Model, vCOMMIT[setUC, setTIME],  Bin) # Commitment
        @variable(EDUC_Model, vSTARTUC[setUC, setTIME], Bin) # Start-ups
        @variable(EDUC_Model, vSHUTUC[setUC, setTIME],  Bin) # Shut-downs

        # Capacities
        @variable(EDUC_Model, vCAPGEN[setGEN]                        >= 0)
        @variable(EDUC_Model, vMAXENGY[union(setSTOR, setHYDRO)]     >= 0)
        @variable(EDUC_Model, vCAPLINE[setLINEFWD]                   >= 0)

        # Operations
        @variable(EDUC_Model, vGENDISPATCH[setGEN, setTIME]          >= 0)
        @variable(EDUC_Model, vCHARGESTOR[setSTOR, setTIME]          >= 0)
        @variable(EDUC_Model, vCHARGEHYDRO[setHYDRO, setTIME]        >= 0)
        @variable(EDUC_Model, vSOCSTOR[setSTOR, setTIME]             >= 0)
        @variable(EDUC_Model, vSOCHYDRO[setHYDRO, setTIME]           >= 0)
        @variable(EDUC_Model, vCURTHYDRO[setHYDRO, setTIME]          >= 0)
        @variable(EDUC_Model, vNSE[setZONE, setSEGMENT, setTIME]     >= 0)
        @variable(EDUC_Model, vFLOWFWD[setLINEFWD, setTIME]          >= 0)
        @variable(EDUC_Model, vFLOWRVS[setLINERVS, setTIME]          >= 0)

        # Reserves
        @variable(EDUC_Model, vRESUP[setGEN, setTIME]           >= 0)
        @variable(EDUC_Model, vRESDOWN[setGEN, setTIME]         >= 0)

        # CONSTRAINTS
        # Installed capacities
        @constraint(EDUC_Model, cMaxCap_UC[g in setUC], vCAPGEN[g]                 == generators.Existing_Cap_MW[g])
        @constraint(EDUC_Model, cMaxCap_WINDSOLAR[g in setWINDSOLAR], vCAPGEN[g]   == generators.Existing_Cap_MW[g])
        @constraint(EDUC_Model, cMaxCap_STOR[g in setSTOR], vCAPGEN[g]             == generators.Existing_Cap_MW[g])
        @constraint(EDUC_Model, cMaxCap_HYDRO[g in setHYDRO], vCAPGEN[g]           == generators.Existing_Cap_MW[g])
        @constraint(EDUC_Model, cMaxEnergy_Stor[g in setSTOR], vMAXENGY[g]         == generators.Existing_Cap_MWh[g])
        @constraint(EDUC_Model, cMaxEnergy_Hydro[g in setHYDRO], vMAXENGY[g]       == generators.Existing_Cap_MWh[g])
        @constraint(EDUC_Model, cMaxCap_LineFwd[l in setLINEFWD], vCAPLINE[l]          == network_fwd.Line_Max_Flow_MW[l])
        @constraint(EDUC_Model, cMaxCap_LineRvs[l in setLINERVS], vCAPLINE[l]          == network_rvs.Line_Max_Flow_MW[l])

        # CHP commitment and derating during heating hours
        for g in setCHP
            temp_z = generators[generators.R_ID .== g, :Zone][1]  
            heattime_column = Symbol("Heat_time_z$temp_z")  
                @constraint(EDUC_Model, [t in setTIME], vCOMMIT[g, t] >= heattime[t, heattime_column])
        
            if  generators[generators.R_ID .== g, :Cap_Size][1] == 200
                @constraint(EDUC_Model, [t in setTIME], vGENDISPATCH[g,t] <= genvar[t,g] * vCOMMIT[g,t] * 155)   # derated to 155
            elseif generators[generators.R_ID .== g, :Cap_Size][1] == 300
                @constraint(EDUC_Model, [t in setTIME], vGENDISPATCH[g,t] <= genvar[t,g] * vCOMMIT[g,t] * 241)   # derated to 241
            elseif generators[generators.R_ID .== g, :Cap_Size][1] == 330
                @constraint(EDUC_Model, [t in setTIME], vGENDISPATCH[g,t] <= genvar[t,g] * vCOMMIT[g,t] * 279)   # derated to 279
            elseif generators[generators.R_ID .== g, :Cap_Size][1] == 600
                @constraint(EDUC_Model, [t in setTIME], vGENDISPATCH[g,t] <= genvar[t,g] * vCOMMIT[g,t] * 410)   # derated to 410
            else
                # No derating data for other sizes
                nothing
            end
        end

        # Generation upper bounds
        @constraint(EDUC_Model, cMaxPower_UC[g in setUC, t in setTIME], vGENDISPATCH[g,t] <= genvar[t,g] * vCOMMIT[g,t] * vCAPGEN[g])
        @constraint(EDUC_Model, cMaxPower_WINDSOLAR[g in setWINDSOLAR, t in setTIME], vGENDISPATCH[g,t] <= genvar[t,g] * vCAPGEN[g]) 
        @constraint(EDUC_Model, cMaxPower_STOR[g in setSTOR, t in setTIME], vGENDISPATCH[g,t] <= genvar[t,g] * vCAPGEN[g])
        @constraint(EDUC_Model, cMaxPower_HYDRO[g in setHYDRO, t in setTIME], vGENDISPATCH[g,t] <= vCAPGEN[g])   

        # Minimum generation
        @constraint(EDUC_Model, cMinPower_UC[g in setUC, t in setTIME], vGENDISPATCH[g,t] >= genvar[t,g] * generators.Min_Power[g] * vCOMMIT[g,t] * vCAPGEN[g])
        @constraint(EDUC_Model, cMinPower_WINDSOLAR[g in setWINDSOLAR, t in setTIME], vGENDISPATCH[g,t] >= generators.Min_Power[g] * vCAPGEN[g])
        @constraint(EDUC_Model, cMinPower_STOR[g in setSTOR, t in setTIME], vGENDISPATCH[g,t] >= generators.Min_Power[g] * vCAPGEN[g])
        @constraint(EDUC_Model, cMinPower_HYDRO[g in setHYDRO, t in setTIME], vGENDISPATCH[g,t] >= generators.Min_Power[g] * vCAPGEN[g])

        # Ramping
        @constraint(EDUC_Model, cRampUp_UC[g in setUC, t in setINTERIORS], vGENDISPATCH[g,t] - vGENDISPATCH[g,t-1] <=
                                        (vCOMMIT[g,t] - vCOMMIT[g,t-1]) * generators.Min_Power[g] * vCAPGEN[g] + vCOMMIT[g,t] * generators.Ramp_Up_Percentage[g] * vCAPGEN[g])
        @constraint(EDUC_Model, cRampUp_NONUC[g in setdiff(setGEN,setUC), t in setINTERIORS], vGENDISPATCH[g,t] - vGENDISPATCH[g,t-1] <= generators.Ramp_Up_Percentage[g] * vCAPGEN[g])
    
        # Ramp down
        @constraint(EDUC_Model, cRampDown_UC[g in setUC, t in setINTERIORS], vGENDISPATCH[g,t-1] - vGENDISPATCH[g,t] <=
                                        (vCOMMIT[g,t-1] - vCOMMIT[g,t]) * generators.Min_Power[g] * vCAPGEN[g] + vCOMMIT[g,t] * generators.Ramp_Dn_Percentage[g] * vCAPGEN[g])
        @constraint(EDUC_Model, cRampDown_NONUC[g in setdiff(setGEN,setUC), t in setINTERIORS], vGENDISPATCH[g,t-1] - vGENDISPATCH[g,t] <= generators.Ramp_Dn_Percentage[g] * vCAPGEN[g])

        # Non-served energy limit
        @constraint(EDUC_Model, cMaxNSE[z in setZONE, t in setTIME], sum(vNSE[z,s,t] for s in setSEGMENT) <= load[t,z])
        
        
        # State of charge limits
        @constraint(EDUC_Model, cMaxSOC_STOR[g in setSTOR, t in setTIME],   vSOCSTOR[g,t]  <= vMAXENGY[g])
        @constraint(EDUC_Model, cMaxSOC_HYDRO[g in setHYDRO, t in setTIME], vSOCHYDRO[g,t] <= vMAXENGY[g])

        # Storage state of charge
        @constraint(EDUC_Model, cSOC_STOR[g in setSTOR, t in setINTERIORS], vSOCSTOR[g,t] == vSOCSTOR[g,t-1] + vCHARGESTOR[g,t] * generators.Eff_Up[g] - vGENDISPATCH[g,t] / generators.Eff_Down[g])        
        @constraint(EDUC_Model, cSOCStart_STOR[g in setSTOR, t = first(setTIME)], vSOCSTOR[g,t] == initfinalstate * vMAXENGY[g] + vCHARGESTOR[g,t] * generators.Eff_Up[g] - vGENDISPATCH[g,t] / generators.Eff_Down[g])
        @constraint(EDUC_Model, cSOCFinal_STOR[g in setSTOR, t = last(setTIME)], vSOCSTOR[g,t] == initfinalstate * vMAXENGY[g])

        # Hydro state of charge
        @constraint(EDUC_Model, cSOC_Hydro1[g in setHYDRO, t in setINTERIORS], vSOCHYDRO[g,t] == vSOCHYDRO[g,t-1] + vCAPGEN[g] * genvar[t,g] * generators.Eff_Up[g] - vCURTHYDRO[g,t] - vGENDISPATCH[g,t] / generators.Eff_Down[g])
        @constraint(EDUC_Model, cSOC_Hydro2[g in setHYDRO, t in setINTERIORS], vCHARGEHYDRO[g,t] == vCAPGEN[g] * genvar[t,g]* generators.Eff_Up[g] - vCURTHYDRO[g,t])
        @constraint(EDUC_Model, cSOCStart_Hydro1[g in setHYDRO, t = first(setTIME)], vSOCHYDRO[g,t] == initfinalstate * vMAXENGY[g] + vCAPGEN[g] * genvar[t,g] * generators.Eff_Up[g] - vCURTHYDRO[g,t] - vGENDISPATCH[g,t] / generators.Eff_Down[g])
        @constraint(EDUC_Model, cSOCStart_Hydro2[g in setHYDRO, t = first(setTIME)], vCHARGEHYDRO[g,t]  == vCAPGEN[g] * genvar[t,g]* generators.Eff_Up[g] - vCURTHYDRO[g,t])
        @constraint(EDUC_Model, cSOCFinal_Hydro[g in setHYDRO, t = last(setTIME)], vSOCHYDRO[g,t] == initfinalstate * vMAXENGY[g])

        # Hydro minimum storage
        @constraint(EDUC_Model, cSOCMinHydro[g in setHYDRO, t in setTIME], vSOCHYDRO[g,t] >= minreservoirlevel * vMAXENGY[g])

        # Commitment bounds
        @constraint(EDUC_Model, cCommitMax[g in setUC, t in setTIME], vCOMMIT[g,t] <= generators.num_units[g])
        @constraint(EDUC_Model, cStartCap[g in setUC, t in setTIME], vSTARTUC[g,t] <= generators.num_units[g])
        @constraint(EDUC_Model, cShutCap[g in setUC, t in setTIME], vSHUTUC[g,t] <= generators.num_units[g])
        @constraint(EDUC_Model, cTransStartShut[g in setUC, t in setdiff(setTIME,1)], vCOMMIT[g,t] - vCOMMIT[g,t-1] == vSTARTUC[g,t] - vSHUTUC[g,t])

        # Minimum up/down time
        @constraint(EDUC_Model, cComSta[g in setUC, t in setdiff(setTIME, 1:maximum(generators.Up_Time[setUC]))],
                                        vCOMMIT[g,t] >= sum(vSTARTUC[g,tt] for tt in round.(Int, Array(t-generators.Up_Time[g]:t))))
        @constraint(EDUC_Model, cComShut[g in setUC, t in setdiff(setTIME, 1:maximum(generators.Down_Time[setUC]))],
                                        generators.num_units[g] - vCOMMIT[g,t] >= sum(vSHUTUC[g,tt] for tt in round.(Int, Array(t-generators.Down_Time[g]:t))))

        # Line limits
        @constraint(EDUC_Model, cMaxFlow1[l in setLINEFWD, t in setTIME], vFLOWFWD[l,t] <= vCAPLINE[l] * (1 - network_fwd.Loss[l]/2))
        @constraint(EDUC_Model, cMaxFlow2[l in setLINERVS, t in setTIME], vFLOWRVS[l,t] <= vCAPLINE[l] * (1 - network_rvs.Loss[l]/2))

        # External lines are one-way
        @constraint(EDUC_Model, cSingleDirectionFlowSD[l in setSDLINERVS, t in setTIME], vFLOWRVS[l,t] == 0)
        @constraint(EDUC_Model, cSingleDirectionFlowJB[l in setJBLINERVS, t in setTIME], vFLOWRVS[l,t] == 0)

        # Nodal balance
        @constraint(EDUC_Model, cDemandBalance[t in setTIME, z in setZONE],
        sum(vGENDISPATCH[g,t] for g in generators[generators.Zone .== z, :R_ID]) +
        sum(vNSE[z,s,t] for s in setSEGMENT) -
        sum(vCHARGESTOR[g,t] for g in intersect(generators[generators.Zone .== z, :R_ID], setSTOR)) -
        load[t,z] -
        sum(network_fwd[l, Symbol(string("z",z))] * vFLOWFWD[l,t] for l in setLINEFWD) -
        sum(abs(network_fwd[l, Symbol(string("z",z))]) * vFLOWFWD[l,t] / (1-network_fwd.Loss[l]/2) * (network_fwd.Loss[l]/2) for l in setLINEFWD) -
        sum(network_rvs[l, Symbol(string("z",z))] * vFLOWRVS[l,t] for l in setLINERVS) -
        sum(abs(network_rvs[l, Symbol(string("z",z))]) * vFLOWRVS[l,t] / (1-network_rvs.Loss[l]/2) * (network_rvs.Loss[l]/2) for l in setLINERVS)  
        == 0
        )

        # Flow-MLT constraints
        if scenario_name in ["MLT", "PriorityMLT", "FlexiblePriorityMLT"]
            temp_setLINE = setLINE
        elseif scenario_name in ["SpotMLT", "FlexibleSpotMLT"]
            temp_setLINE = setExtLINE # external only
        elseif scenario_name in ["SpotOnly", "PrioritySpot",  "FlexiblePrioritySpot"]
            temp_setLINE = []
            println(scenario_name ," scenario is running; not limit MLT-vFLOW balance")
        else
            temp_setLINE = []
            println(scenario_name ," Error: NO scenario is running!!!; not limit MLT-vFLOW balance")
        end
        for l in temp_setLINE
            loss_rate = network_fwd[network_fwd.Network_Lines .== l, :Loss][1]
            line_name = network_fwd[network_fwd.Network_Lines .== l, :transmission_path_name][1]
            println("Lines limited by MLT include: ", line_name)
            for t in setTIME[1:end]
                if mlt[t,line_name] >= 0
                    @constraint(EDUC_Model, vFLOWFWD[l, t] <= 1.1*mlt[t,line_name] * (1-loss_rate/2)) # 5 percent upper bound
                    @constraint(EDUC_Model, vFLOWFWD[l, t] >= 0.9*mlt[t,line_name] * (1-loss_rate/2)) # 5 percent lower bound
                    # @constraint(EDUC_Model, vFLOWFWD[l, t] == mlt[t,line_name] * (1-loss_rate/2))
                    @constraint(EDUC_Model, vFLOWRVS[l, t] == 0)
                else
                    @constraint(EDUC_Model, vFLOWFWD[l, t] == 0)
                    # @constraint(EDUC_Model, vFLOWRVS[l, t] == abs(mlt[t,line_name] * (1-loss_rate/2)))
                    @constraint(EDUC_Model, vFLOWRVS[l, t] <= 1.1*abs(mlt[t,line_name] * (1-loss_rate/2))) # upper bound
                    @constraint(EDUC_Model, vFLOWRVS[l, t] >= 0.9*abs(mlt[t,line_name] * (1-loss_rate/2))) # lower bound
                end
            end
        end

        # Reserve: UC
        @constraint(EDUC_Model, cResUp_UC1[g in setUC, t in setTIME], vRESUP[g,t] <= vCOMMIT[g,t] * vCAPGEN[g])
        @constraint(EDUC_Model, cResUp_UC2[g in setUC, t in setTIME], vRESUP[g,t] <= vCOMMIT[g,t] * vCAPGEN[g] - vGENDISPATCH[g,t])
        @constraint(EDUC_Model, cResUp_UC3[g in setUC, t in setTIME], vRESUP[g,t] <= vCOMMIT[g,t] * generators.Ramp_Up_Percentage[g] * vCAPGEN[g])
        @constraint(EDUC_Model, cResDown_UC1[g in setUC, t in setTIME], vRESDOWN[g,t] <= vCOMMIT[g,t] * vCAPGEN[g])
        @constraint(EDUC_Model, cResDown_UC2[g in setUC, t in setTIME], vRESDOWN[g,t] <= vCOMMIT[g,t] * vGENDISPATCH[g,t] - vCOMMIT[g,t] * generators.Min_Power[g] * vCAPGEN[g])
        @constraint(EDUC_Model, cResDown_UC3[g in setUC, t in setTIME], vRESDOWN[g,t] <= vCOMMIT[g,t] * generators.Ramp_Dn_Percentage[g] * vCAPGEN[g])

        # Reserve: Wind/Solar
        @constraint(EDUC_Model, cResUp_WindSolar1[g in setWINDSOLAR, t in setTIME], vRESUP[g,t] <= genvar[t,g] * vCAPGEN[g])
        @constraint(EDUC_Model, cResUp_WindSolar2[g in setWINDSOLAR, t in setTIME], vRESUP[g,t] <=  genvar[t,g] * vCAPGEN[g] - vGENDISPATCH[g,t])
        @constraint(EDUC_Model, cResUp_WindSolar3[g in setWINDSOLAR, t in setTIME], vRESUP[g,t] <= generators.Ramp_Up_Percentage[g] * vCAPGEN[g])
        @constraint(EDUC_Model, cResDown_WindSolar1[g in setWINDSOLAR, t in setTIME], vRESDOWN[g,t] <= genvar[t,g] * vCAPGEN[g])
        @constraint(EDUC_Model, cResDown_WindSolar2[g in setWINDSOLAR, t in setTIME], vRESDOWN[g,t] <= vGENDISPATCH[g,t] - generators.Min_Power[g] * genvar[t,g] * vCAPGEN[g])
        @constraint(EDUC_Model, cResDown_WindSolar3[g in setWINDSOLAR, t in setTIME], vRESDOWN[g,t] <= generators.Ramp_Dn_Percentage[g] * vCAPGEN[g])

        # Reserve: Storage
        @constraint(EDUC_Model, cResUp_Stor1[g in setSTOR, t in setTIME], vRESUP[g,t] <= vCAPGEN[g])
        @constraint(EDUC_Model, cResUp_Stor2[g in setSTOR, t in setTIME], vRESUP[g,t] + vGENDISPATCH[g,t] <= vCAPGEN[g])
        @constraint(EDUC_Model, cResUp_Stor3[g in setSTOR, t in setTIME], vRESUP[g,t] <= vMAXENGY[g] * generators.Eff_Down[g] - vGENDISPATCH[g,t])
        @constraint(EDUC_Model, cResUp_Stor4[g in setSTOR, t in setTIME], vRESUP[g,t] <= vSOCSTOR[g,t] * generators.Eff_Down[g])
        @constraint(EDUC_Model, cResUp_Stor5[g in setSTOR, t in setTIME], vRESUP[g,t] <= generators.Ramp_Up_Percentage[g] * vCAPGEN[g])
        @constraint(EDUC_Model, cResDown_Stor1[g in setSTOR, t in setTIME], vRESDOWN[g,t] <= vCAPGEN[g])
        @constraint(EDUC_Model, cResDown_Stor2[g in setSTOR, t in setTIME], vRESDOWN[g,t] <= vMAXENGY[g] * generators.Eff_Down[g] - vSOCSTOR[g,t] * generators.Eff_Down[g])
        @constraint(EDUC_Model, cResDown_Stor3[g in setSTOR, t in setTIME], vRESDOWN[g,t] <= generators.Ramp_Dn_Percentage[g] * vCAPGEN[g])
        @constraint(EDUC_Model, cResUpAndDown_Stor[g in setSTOR, t in setTIME], (vGENDISPATCH[g,t] + vRESUP[g,t]) / generators.Eff_Down[g] + (vCHARGESTOR[g,t] + vRESDOWN[g,t]) * generators.Eff_Up[g] <= vCAPGEN[g])

        # Reserve: Hydro
        @constraint(EDUC_Model, cResUp_Hydro1[g in setHYDRO, t in setTIME], vRESUP[g,t] <= vCAPGEN[g])  
        @constraint(EDUC_Model, cResUp_Hydro2[g in setHYDRO, t in setTIME], vRESUP[g,t] + vGENDISPATCH[g,t] <= vCAPGEN[g])
        @constraint(EDUC_Model, cResUp_Hydro3[g in setHYDRO, t in setTIME], vRESUP[g,t] <= vMAXENGY[g] * generators.Eff_Down[g] - vGENDISPATCH[g,t])
        @constraint(EDUC_Model, cResUp_Hydro4[g in setHYDRO, t in setTIME], vRESUP[g,t] <= vSOCHYDRO[g,t] * generators.Eff_Down[g])
        @constraint(EDUC_Model, cResUp_Hydro5[g in setHYDRO, t in setTIME], vRESUP[g,t] <= generators.Ramp_Up_Percentage[g] * vCAPGEN[g])
        @constraint(EDUC_Model, cResDown_Hydro1[g in setHYDRO, t in setTIME], vRESDOWN[g,t] <= vCAPGEN[g])
        @constraint(EDUC_Model, cResDown_Hydro2[g in setHYDRO, t in setTIME], vRESDOWN[g,t] <= (vMAXENGY[g] - minreservoirlevel - vSOCHYDRO[g,t]) * generators.Eff_Down[g])
        @constraint(EDUC_Model, cResDown_Hydro3[g in setHYDRO, t in setTIME], vRESUP[g,t] <= generators.Ramp_Dn_Percentage[g] * vCAPGEN[g])

        # Reserve: zonal requirements
        @constraint(EDUC_Model, cTotResUp[z in setZONE, t in setTIME],
            sum(vRESUP[g,t] for g in intersect(setGEN, generators[generators.Zone .== z, :R_ID])) >=
            first(operatingres[operatingres.Zones .== z, :Load]) * (load[t,z]) +
            first(operatingres[operatingres.Zones .== z, :Renewable]) * sum(vGENDISPATCH[g,t] for g in intersect(setWINDSOLAR, generators[generators.Zone .== z, :R_ID])) +
            contn1[z]
            )
        @constraint(EDUC_Model, cTotResDown[z in setZONE, t in setTIME],
            sum(vRESDOWN[g,t] for g in intersect(setGEN, generators[generators.Zone .== z, :R_ID])) >=
            first(operatingres[operatingres.Zones .== z, :Load]) * (load[t,z]) +
            first(operatingres[operatingres.Zones .== z, :Renewable]) * sum(vGENDISPATCH[g,t] for g in intersect(setWINDSOLAR, generators[generators.Zone .== z, :R_ID]))
            )

        # Objective components
        @expression(EDUC_Model, eVarCostGen, sum(sample_weight[t] * Var_Cost[g,(t+(count-1)*hours_per_period)] * vGENDISPATCH[g,t] for g in setGEN, t in setTIME))
        @expression(EDUC_Model, eNSECosts, sum(sample_weight[t] * first(nse[(nse.Zone .== z) .& (nse.Segment .== s), :NSE_Cost]) * vNSE[z,s,t] for z in setZONE, s in setSEGMENT, t in setTIME))
        @expression(EDUC_Model, eStartCostUC, sum(Start_Cost[g,(t+(count-1)*hours_per_period)] * generators.Cap_Size[g] * vSTARTUC[g,t] for g in setUC, t in setTIME))
        # Define the objective function
        @objective(EDUC_Model, Min, eVarCostGen + eNSECosts + eStartCostUC) 

        optimize!(EDUC_Model)


        if isdir(joinpath(resultpath, string(count))) == false
            mkdir(joinpath(resultpath, string(count)))
        else
            rm(joinpath(resultpath, string(count)), recursive = true)
            mkdir(joinpath(resultpath, string(count)))
        end

        if isdir(joinpath(dispatchpath, string(count))) == false
            mkdir(joinpath(dispatchpath, string(count)))
        else
            rm(joinpath(dispatchpath, string(count)), recursive = true)
            mkdir(joinpath(dispatchpath, string(count)))
        end

        println("setSTARTS is ", setSTARTS)
        
        if termination_status(EDUC_Model) == MOI.OPTIMAL || termination_status(EDUC_Model) == MOI.TIME_LIMIT 
            println("################################")
            println("Week ", count, " is feasible!!!")
            println("################################")

            othergenopr = [vCOMMIT, vSTARTUC, vSHUTUC, vCHARGESTOR, vSOCSTOR, vCHARGEHYDRO, vSOCHYDRO, vRESUP, vRESDOWN, vGENDISPATCH]
            flow = vFLOWFWD .+ (-vFLOWRVS)

            RecordCSV(othergenopr, vFLOWFWD, vFLOWRVS, flow, vNSE, vCAPGEN, genvar, count)
            
            costs = DataFrame()
            cost_names = ["eVarCostGen", "eNSECosts", "eStartCostUC"]
            cost_values = [value.(eVarCostGen), value.(eNSECosts), value.(eStartCostUC)]
            costs.Component = cost_names
            costs.Values = cost_values
            CSV.write(joinpath(resultpath, string(count), "cost_components.csv"), costs)

        

            # RecordPlot(vNSE, vGENDISPATCH, vCHARGESTOR, count)
            ProcessDispatch(vGENDISPATCH, vCHARGESTOR, count)

        elseif termination_status(EDUC_Model) == MOI.INFEASIBLE || termination_status(EDUC_Model) == MOI.INFEASIBLE_OR_UNBOUNDED nothing
        else # Other statuses
            println("#########################")
            println("Solution status is other than optimal, time limit, infeasible, and unbounded")
            println("#########################")
        end
    end
end