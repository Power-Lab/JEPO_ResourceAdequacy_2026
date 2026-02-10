# 2 parts in total

################################################
################################################
################################################
### Part 1: Combine (and record) dispatch data for 12 weeks and 6 provinces
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
from pathlib import Path
from datetime import date, timedelta

import numpy as np
import pandas as pd


def ensure_numeric(df: pd.DataFrame) -> pd.DataFrame:
    """
    Convert all object-type columns to numeric; values that cannot be converted become NaN.
    """
    for col in df.columns:
        if df[col].dtype == "object":
            df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


def generate_all_dates(start_date_str: str, n_weeks: int = 12,
                       n_tech: int = 12, n_prov: int = 6) -> pd.Series:
    """
    Generate the date vector all_dates following the R code logic:

    - From start_date, each week has 7 days, each day has 24 hours → 168 time points per week;
    - For each week of 168 hours:
        - Repeat 12 times (12 technologies);
        - Then repeat 6 times (6 provinces);
    - The whole pattern is repeated for n_weeks weeks.
    """
    start_date = date.fromisoformat(start_date_str)
    all_dates = []

    for week in range(n_weeks):
        current_start = start_date + timedelta(weeks=week)
        # 7 days in this week
        weekly_days = [current_start + timedelta(days=i) for i in range(7)]
        # Repeat each day 24 times (hours)
        weekly_dates = np.repeat(weekly_days, 24)  # 7*24 = 168
        # Repeat for n_tech technologies
        tech_dates = np.tile(weekly_dates, n_tech)
        # Repeat for n_prov provinces
        prov_dates = np.tile(tech_dates, n_prov)
        all_dates.extend(prov_dates)

    all_dates = pd.to_datetime(all_dates)
    return all_dates


def main():
    # Get the parent directory of the current working directory
    parent_dir = Path.cwd().parent
    print(f"[INFO] Current working directory: {Path.cwd()}")
    print(f"[INFO] Parent directory (parent_dir): {parent_dir}\n")

    # Scenario paths
    PriorityMLT = parent_dir / "Results_ne_2021_PriorityMLT"
    MLT = parent_dir / "Results_ne_2021_MLT"
    SpotMLT = parent_dir / "Results_ne_2021_SpotMLT"
    FlexibleSpotMLT = parent_dir / "Results_ne_2021_FlexibleSpotMLT"

    results_paths = [
        PriorityMLT,
        MLT,
        SpotMLT,
        FlexibleSpotMLT,
    ]

    # Weeks 1–12 (as strings)
    week_list = [str(i) for i in range(1, 13)]
    prov_list = ["HL", "IME", "JL", "LN", "SD", "JB"]

    # Defined but not used; kept for consistency with the original R code
    required_tech_values = [
        "net_export", "charge", "nuclear", "coal", "hydro",
        "wind", "solar", "store", "net_import", "nse", "demand"
    ]

    # Loop over each scenario path
    for path in results_paths:
        path = Path(path)
        print(f"\n==============================")
        print(f"[SCENARIO] Processing scenario: {path}")
        print(f"            Directory exists: {path.exists()}")
        print(f"==============================\n")

        combined_12_week_data = None  # Store merged data for 12 weeks and 6 provinces

        for w in week_list:
            print(f"[WEEK] Scenario {path.name} - processing week {w}")
            # For each week, merge data of 6 provinces
            combined_data = None

            # ---------- vFlow_results.csv (read once per week) ----------
            flow_file = path / w / "vFlow_results.csv"
            print(f"  [FLOW] Reading flow file: {flow_file}")
            temp_flow = pd.read_csv(flow_file)
            # Transpose and drop the first two rows
            temp_flow = temp_flow.transpose().iloc[2:, :].copy()
            temp_flow.columns = [
                "HL_to_IME", "HL_to_JL", "IME_to_JL", "IME_to_LN",
                "JL_to_LN", "IME_to_SD", "LN_to_JB"
            ]
            temp_flow = ensure_numeric(temp_flow)
            print(f"  [FLOW] Shape of temp_flow after processing: {temp_flow.shape}")

            # Compute net imports for each province
            temp_flow["HL_net_import"] = -(temp_flow["HL_to_IME"] + temp_flow["HL_to_JL"])
            temp_flow["IME_net_import"] = (
                temp_flow["HL_to_IME"]
                - temp_flow["IME_to_JL"]
                - temp_flow["IME_to_LN"]
                - temp_flow["IME_to_SD"]
            )
            temp_flow["JL_net_import"] = (
                temp_flow["HL_to_JL"]
                + temp_flow["IME_to_JL"]
                - temp_flow["JL_to_LN"]
            )
            temp_flow["LN_net_import"] = (
                temp_flow["IME_to_LN"]
                + temp_flow["JL_to_LN"]
                - temp_flow["LN_to_JB"]
            )
            temp_flow["SD_net_import"] = temp_flow["IME_to_SD"]
            temp_flow["JB_net_import"] = temp_flow["LN_to_JB"]

            # ---------- NSE data (read once per week) ----------
            nse_files = [
                path / w / "vNSE1.csv",
                path / w / "vNSE2.csv",
                path / w / "vNSE3.csv",
                path / w / "vNSE4.csv",
                path / w / "vNSE5.csv",
                path / w / "vNSE6.csv",
            ]
            nse_list = []
            for idx, f in enumerate(nse_files, start=1):
                print(f"  [NSE] Reading NSE file vNSE{idx}: {f}")
                df_nse = pd.read_csv(f)
                df_nse = df_nse.transpose().iloc[1:, :]
                nse_list.append(df_nse.reset_index(drop=True))

            temp_NSE = pd.concat(nse_list, axis=1)
            temp_NSE.columns = ["HL_NSE", "IME_NSE", "JL_NSE", "LN_NSE", "SD_NSE", "JB_NSE"]
            temp_NSE = ensure_numeric(temp_NSE)
            print(f"  [NSE] Shape of temp_NSE after merging: {temp_NSE.shape}")

            # ---------- Province-level processing ----------
            for p in prov_list:
                print(f"    [PROV] Processing province: {p}")

                # Dispatch file for generation technologies
                dispatch_file = path / "Dispatch" / w / f"{p}_1.csv"
                print(f"      [DISPATCH] Reading: {dispatch_file}")
                temp_1 = pd.read_csv(dispatch_file)
                print(f"      [DISPATCH] Original temp_1 shape: {temp_1.shape}")

                # Check if all required columns exist
                required_columns = ["NUCLEAR", "COAL", "GAS", "HYDRO", "WIND", "SOLAR", "STOR"]
                missing_cols = []
                for col in required_columns:
                    if col not in temp_1.columns:
                        temp_1[col] = 0.0
                        missing_cols.append(col)
                if missing_cols:
                    print(f"      [DISPATCH] Missing columns filled with zeros: {missing_cols}")
                else:
                    print(f"      [DISPATCH] All required columns present.")

                # Storage charging file
                charge_file = path / "Dispatch" / w / f"{p}_charge_STOR.csv"
                if charge_file.exists():
                    print(f"      [CHARGE] Reading storage charge file: {charge_file}")
                    temp_charge = pd.read_csv(charge_file)
                    before_nonpos = (temp_charge["CHARGE"] <= 0).sum()
                    temp_charge["CHARGE"] = temp_charge["CHARGE"].where(
                        temp_charge["CHARGE"] > 0, 1e-10
                    )
                    after_nonpos = (temp_charge["CHARGE"] <= 0).sum()
                    print(
                        f"      [CHARGE] Number of CHARGE <= 0: {before_nonpos}, "
                        f"after replacement: {after_nonpos}"
                    )
                else:
                    print(
                        f"      [CHARGE] Charge file not found: {charge_file}, "
                        f"creating 168 rows of constant 1e-10"
                    )
                    # If file not found, create 168 rows of constant 1e-10
                    temp_charge = pd.DataFrame({"CHARGE": np.full(168, 1e-10)})

                # Select NSE for current province
                nse_col = f"{p}_NSE"
                temp_NSE_raw = temp_NSE[[nse_col]].copy()
                temp_NSE_raw = temp_NSE_raw.rename(columns={nse_col: "NSE"})

                # NET import/export
                net_col = f"{p}_net_import"
                temp_net_import = temp_flow[[net_col]].copy()
                temp_net_import = temp_net_import.rename(columns={net_col: "NET"})

                # Assemble temp
                # Note: in R this is cbind(temp_1, -1 * temp_charge)
                temp = pd.concat(
                    [temp_1.reset_index(drop=True), -1 * temp_charge.reset_index(drop=True)],
                    axis=1,
                )
                temp = pd.concat(
                    [temp, temp_NSE_raw.reset_index(drop=True), temp_net_import.reset_index(drop=True)],
                    axis=1,
                )

                temp = ensure_numeric(temp)

                # Handle NET_IMPORT / NET_EXPORT
                temp["NET_IMPORT"] = np.where(temp["NET"] >= 0, temp["NET"], 1e-10)
                temp["NET_EXPORT"] = np.where(temp["NET"] < 0, temp["NET"], -1e-10)
                temp = temp.drop(columns=["NET"])

                # Reorder columns
                new_column_order = [
                    "NET_EXPORT",
                    "CHARGE",
                    "NUCLEAR",
                    "COAL",
                    "GAS",
                    "HYDRO",
                    "WIND",
                    "SOLAR",
                    "STOR",
                    "NET_IMPORT",
                    "NSE",
                ]
                temp = temp[new_column_order].copy()

                # Compute demand
                temp1 = temp.copy()
                demand_df = pd.DataFrame()
                demand_df["DEMAND"] = temp1.sum(axis=1)
                demand_df["time"] = np.arange(1, len(demand_df) + 1)

                # Convert to long format (similar to gather)
                temp_long = temp.copy()
                temp_long["time"] = np.arange(1, len(temp_long) + 1)
                temp_long = temp_long.melt(
                    id_vars=["time"],
                    var_name="tech",
                    value_name="dispatch",
                )

                # Convert tech column to lowercase
                temp_long["tech"] = temp_long["tech"].str.lower()

                # Append demand, add zone and period
                demand_long = demand_df.copy()
                demand_long["tech"] = "demand"
                demand_long = demand_long.rename(columns={"DEMAND": "dispatch"})
                demand_long = demand_long[["time", "tech", "dispatch"]]

                temp_combined = pd.concat([temp_long, demand_long], ignore_index=True)
                temp_combined["zone"] = p.lower()
                temp_combined["period"] = f"2021 week {w}"

                # time → hour
                temp_combined = temp_combined.rename(columns={"time": "hour"})
                print(f"      [COMBINED] temp_combined shape: {temp_combined.shape}")

                # Save province-week CSV
                out_file = path / w / f"Dispatch_Week{w}_{p}.csv"
                if out_file.exists():
                    os.remove(out_file)
                    print(f"      [FILE] Removed existing file: {out_file}")
                # Keep index to mimic default R write.csv(row.names = TRUE)
                temp_combined.to_csv(out_file, index=True)
                print(f"      [FILE] Wrote province-week file: {out_file}")

                # Read back and append to weekly combined_data (mimicking R behavior)
                temp_combined_read = pd.read_csv(out_file)
                print(f"      [FILE] Read back {out_file}, shape: {temp_combined_read.shape}")

                if combined_data is None:
                    combined_data = temp_combined_read
                else:
                    combined_data = pd.concat(
                        [combined_data, temp_combined_read], ignore_index=True
                    )

            # Remove the first column (row index), equivalent to select(-1) in R
            combined_data = combined_data.drop(columns=combined_data.columns[0])
            print(
                f"  [WEEK] Shape after merging 6 provinces for week {w} "
                f"(first column dropped): {combined_data.shape}"
            )

            # Save 6-province weekly merged CSV
            week_out_file = path / w / f"Dispatch_Week{w}_6zone.csv"
            if week_out_file.exists():
                os.remove(week_out_file)
                print(f"  [FILE] Removed existing weekly merged file: {week_out_file}")
            combined_data.to_csv(week_out_file, index=False)
            print(f"  [FILE] Wrote 6-province merged file for week {w}: {week_out_file}")

            # Append weekly data to the 12-week combined dataset
            if combined_12_week_data is None:
                combined_12_week_data = combined_data.copy()
            else:
                combined_12_week_data = pd.concat(
                    [combined_12_week_data, combined_data], ignore_index=True
                )
            print(
                f"  [ACCUM] Shape of combined_12_week_data up to week {w}: "
                f"{combined_12_week_data.shape}"
            )

        # ---------- Generate date vector and write hourly file with dates ----------
        print("\n[DATE] Generating date sequence all_dates...")
        all_dates = generate_all_dates("2021-08-09", n_weeks=12, n_tech=12, n_prov=6)
        print(f"[DATE] Length of all_dates: {len(all_dates)}")
        print(f"[DATE] Number of rows in combined_12_week_data: {len(combined_12_week_data)}")

        if len(all_dates) != len(combined_12_week_data):
            raise ValueError(
                f"Date vector length ({len(all_dates)}) does not match "
                f"number of rows in data ({len(combined_12_week_data)})!"
            )

        combined_12_week_data["date"] = all_dates
        hourly_out_file = path / "Dispatch_houdrly_6zone_12Weeks_withDates.csv"
        combined_12_week_data.to_csv(hourly_out_file, index=False)
        print(f"[FILE] Wrote 12-week hourly file with dates: {hourly_out_file}")
        print(f"[INFO] Preview of combined_12_week_data with dates (first 5 rows):")
        print(combined_12_week_data.head(), "\n")

        # ---------- Monthly aggregation (September and October), write wide tables ----------
        combined_12_week_data["date"] = pd.to_datetime(combined_12_week_data["date"])

        for month_num in (9, 10):
            print(f"[MONTH] Aggregating data for month {month_num}...")
            month_data = combined_12_week_data[
                combined_12_week_data["date"].dt.month == month_num
            ].copy()
            print(f"[MONTH] Number of rows in month {month_num} data: {len(month_data)}")

            # Ensure dispatch is numeric
            month_data["dispatch"] = pd.to_numeric(
                month_data["dispatch"], errors="coerce"
            )

            month_summary = (
                month_data.groupby(["zone", "tech"], as_index=False)["dispatch"]
                .sum(min_count=1)
                .rename(columns={"dispatch": "total_dispatch"})
            )
            print(
                f"[MONTH] Shape of month_summary for month {month_num}: "
                f"{month_summary.shape}"
            )

            wide_month = month_summary.pivot_table(
                index="zone",
                columns="tech",
                values="total_dispatch",
                fill_value=0,
                aggfunc="sum",
            ).reset_index()

            # Reset column index name
            wide_month.columns.name = None

            month_str = f"{month_num:02d}"
            out_month_file = path / f"Dispatch_monthly(sum)_{month_str}.csv"
            wide_month.to_csv(out_month_file, index=False)
            print(f"[FILE] Wrote wide monthly file for month {month_str}: {out_month_file}")
            print(f"[MONTH] Preview of wide monthly table for month {month_str}:")
            print(wide_month.head(), "\n")

    print("\n[ALL DONE] All scenarios processed ✅")


if __name__ == "__main__":
    main()


################################################
################################################
################################################
# Part 2: Plot combined dispatch and demand charts

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
from matplotlib.gridspec import GridSpec
from pathlib import Path

def process_scenario(base_path, scenario, week_number, tech_order=None):
    """Process a single scenario, filter data, and generate charts."""
    # Default technology order
    if tech_order is None:
        tech_order = ['charge', 'nuclear', 'coal', 'hydro', 'gas', 'wind', 'solar', 'stor', 'nse']

    # Technology color mapping
    tech_colors = {
        'charge': 'darkorchid',  # Dark purple
        'nuclear': 'tomato',  # Pink
        'coal': 'dimgrey',  # Brown
        'hydro': 'deepskyblue',  # Sky blue
        'gas': 'violet',
        'wind': 'limegreen',  # Green
        'solar': 'orange',  # Orange
        'stor': 'yellow',  # Yellow
        'nse': 'crimson',  # Red
        'Demand': '#000000'  # Demand color is black
    }
    
    # Construct file path
    file_path = f"../Results_ne_2021_{scenario}/Dispatch_houdrly_6zone_12Weeks_withDates.csv"
    print(f"Processing file: {file_path}")
    
    # Read data
    try:
        df = pd.read_csv(file_path)
    except FileNotFoundError:
        print(f"File not found: {file_path}")
        return
    except Exception as e:
        print(f"Error reading file: {e}")
        return

    # Verify required columns exist
    required_columns = {'period', 'tech', 'zone', 'hour', 'dispatch'}
    if not required_columns.issubset(df.columns):
        print(f"File is missing required columns: {required_columns - set(df.columns)}")
        return

    # Filter data for the specified week number
    df['week'] = df['period'].str.extract(r'week (\d+)').astype(int)  # Extract week number
    filtered_df = df[df['week'] == week_number]

    # Remove rows where the tech column is net_export or net_import
    filtered_df = filtered_df[~filtered_df['tech'].isin(['net_export', 'net_import'])]

    # Extract demand data
    demand_df = filtered_df[filtered_df['tech'] == 'demand'].groupby('hour')['dispatch'].sum()
    
    # Group by tech and sum dispatch for each zone (excluding demand)
    filtered_df = filtered_df[filtered_df['tech'] != 'demand']
    grouped = filtered_df.groupby(['tech', 'hour'])['dispatch'].sum().reset_index()

    # Create data for stacked area chart
    pivot_table = grouped.pivot(index='hour', columns='tech', values='dispatch').fillna(0)

    # Ensure dispatch values between -0.01 and 0.01 are set to 0
    pivot_table = pivot_table.applymap(lambda x: 0 if -0.01 < x < 0.01 else x)

    # Adjust the order of technologies and reverse
    pivot_table = pivot_table.reindex(columns=tech_order, fill_value=0)

    # Check data consistency
    if pivot_table.empty or demand_df.empty:
        print(f"{scenario} Week {week_number} data is empty, cannot generate chart.")
        return

    # Create combined chart
    fig, ax1 = plt.subplots(figsize=(12, 7))

    # Plot stacked area chart
    pivot_table.plot(kind='area', stacked=True, ax=ax1, legend=False,
                     color=[tech_colors.get(tech, '#000000') for tech in pivot_table.columns])

    # Plot demand line chart on the same Y-axis
    ax1.plot(demand_df.index, demand_df.values, color='black', linestyle='--', label='Demand')

    # Set minimum value for y-axis
    ax1.set_ylim(bottom = -5000)
    # Format y-axis numbers with commas
    ax1.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f'{int(x):,}'))
    # Add horizontal grid lines
    ax1.yaxis.grid(True, linestyle='--', linewidth=0.5, color='grey', alpha=0.4)

    ax1.set_xlim(0, 168)  # Ensure x-axis range is 0 to 168
    ax1.set_xticks([0] + list(range(24, 169, 24)))  # Add 0 tick and set intervals
    ax1.set_xticklabels([str(x) for x in [0] + list(range(24, 169, 24))])  # Ensure 0 is displayed

    # Remove margins on x-axis
    ax1.set_xlim(left=0 , right=169)


    # Set title and axes labels
    ax1.set_title(f"{scenario}", fontsize=34)
    ax1.set_xlabel("Hour", fontsize=22)
    ax1.set_ylabel("Dispatch and Demand (MW)", fontsize=22)
    ax1.tick_params(axis='y', labelsize=22)  # Increase Y-axis label font size
    ax1.tick_params(axis='x', labelsize=22)  # Increase X-axis label font size
    plt.tight_layout()

    # # Save chart to file or display directly (single scenario chart)
    output_path = f"temp/Plot_Dispatch_{scenario}_week{week_number}.png"
    plt.savefig(output_path)
    print(f"Chart successfully saved to: {output_path}")

    # Save legend as a separate image
    legend_fig = plt.figure(figsize=(6, 4))  # Set legend image size
    legend_ax = legend_fig.add_subplot(111)
    legend_ax.axis('off')  # Turn off axes

    # Regenerate handles and labels
    fresh_handles = [plt.Line2D([0], [0], color=tech_colors.get(tech, '#000000'), lw=8) for tech in tech_order]
    fresh_labels = [label_mapping.get(tech, tech.capitalize()) for tech in tech_order]
    # Ensure Demand legend style is black dashed line
    fresh_handles.append(plt.Line2D([0], [0], color='black', linestyle='--', lw=4))
    fresh_labels.append('Demand')  # Ensure it matches dashed line style

    # Create new legend object
    legend = legend_ax.legend(fresh_handles, fresh_labels, 
                              title="Tech", loc='center', fontsize=18)
    legend.get_title().set_fontsize(22)

    # # Save legend to file
    legend_output_path = f"temp/Legend_{scenario}_week{week_number}.png"
    print(f"Attempting to save legend to: {legend_output_path}")
    legend_fig.savefig(legend_output_path, bbox_inches='tight')
    print(f"Legend successfully saved to: {legend_output_path}")
    # plt.close(legend_fig)

    # print(f"Legend saved to: {legend_output_path}")

# Define label_mapping dictionary
label_mapping = {
    'stor': 'Storage',
    'charge': 'Charge',
    'nuclear': 'Nuclear',
    'coal': 'Coal',
    'hydro': 'Hydro',
    'gas': 'Gas',
    'wind': 'Wind',
    'solar': 'Solar',
    'nse': 'NSE',
    'demand': 'Demand'
}

# Parameters
scenario_list = ["PriorityMLT", "MLT", "SpotMLT", "FlexibleSpotMLT"]
week_number = 7


# Replace __file__ with a hardcoded path for debugging
script_dir = Path(__file__).resolve().parent
base_path = script_dir / f"temp"

# Loop through each scenario
for scenario in scenario_list:
    process_scenario(base_path, scenario, week_number)

def combine_plots(base_path, scenario_list, week_number):
    """Combine four charts into a single 2x2 image."""
    fig = plt.figure(figsize=(16, 10))  # Set overall image size
    gs = GridSpec(2, 2, figure=fig)  # Create 2x2 grid

    for i, scenario in enumerate(scenario_list):
        row, col = divmod(i, 2)  # Calculate subplot position
        ax = fig.add_subplot(gs[row, col])

        # Load image for each scenario
        img_path = base_path / f"Plot_Dispatch_{scenario}_week{week_number}.png"
        print(f"Attempting to read image file: {img_path}")
        if not img_path.exists():
            print(f"Error: File does not exist: {img_path}")
            continue
        img = plt.imread(img_path)
        print(f"Successfully read image file: {img_path}")
        ax.imshow(img)
        ax.axis('off')  # Turn off axes
        # Remove subplot title
        # ax.set_title(scenario, fontsize=16)

    # # Save combined image
    # combined_output_path = f"Combined_Plots_week{week_number}.png"
    # plt.tight_layout()
    # plt.savefig(combined_output_path, bbox_inches='tight')
    # print(f"Combined image saved to: {combined_output_path}")

# Call combine_plots at the end of the script
combine_plots(base_path, scenario_list, week_number)

def combine_plots_with_legend(base_path, scenario_list, week_number):
    """Combine four charts into a single 2x2 image and add a legend in the top right corner."""
    fig = plt.figure(figsize=(13, 8))  # Increase width to leave space on the right
    gs = GridSpec(2, 2, figure=fig, wspace=0.01, hspace=0.01, left=0.05, right=0.85)  # Minimize horizontal and vertical spacing

    for i, scenario in enumerate(scenario_list):
        row, col = divmod(i, 2)  # Calculate subplot position
        ax = fig.add_subplot(gs[row, col])

        # Load image for each scenario
        img_path = base_path / f"Plot_Dispatch_{scenario}_week{week_number}.png"
        print(f"Attempting to read image file: {img_path}")
        if not img_path.exists():
            print(f"Error: File does not exist: {img_path}")
            continue
        img = plt.imread(img_path)
        print(f"Successfully read image file: {img_path}")
        ax.imshow(img)
        ax.axis('off')  # Turn off axes

    # Add legend to the top right corner
    legend_ax = fig.add_axes([0.85, 0.5, 0.1, 0.3])  # Adjust position, move down slightly
    legend_ax.axis('off')  # Turn off axes

    # Example legend content
    tech_colors = {
        'charge': 'darkorchid', 'nuclear': 'tomato', 'coal': 'dimgrey',
        'hydro': 'deepskyblue', 'gas': 'violet', 'wind': 'limegreen',
        'solar': 'orange', 'stor': 'yellow', 'nse': 'crimson', 'Demand': '#000000'
    }
    # Place Demand at the top of the legend
    handles = [plt.Line2D([0], [0], color='black', linestyle='--', lw=2)]  # Add dashed line style
    labels = ['Demand']
    handles.extend([plt.Line2D([0], [0], color=color, lw=4) for color in reversed(list(tech_colors.values())) if color != '#000000'])
    labels.extend([label.capitalize() for label in reversed(list(tech_colors.keys())) if label != 'Demand'])

    legend = legend_ax.legend(handles, labels, title="Tech", loc='center', fontsize=12, frameon=False)  # Remove border
    legend.get_title().set_fontsize(14)
    # Align legend title to the left and align with the left edge of color blocks
    legend.get_title().set_ha('left')
    legend._legend_box.align = "left"

    # Save combined image
    combined_output_path =  f"figure5.png"
    plt.tight_layout()
    plt.savefig(combined_output_path, bbox_inches='tight', dpi=300)
    #plt.show()

    print(f"Combined image saved to: {combined_output_path}")

# Call combine_plots_with_legend at the end of the script
combine_plots_with_legend(base_path, scenario_list, week_number)

# Ensure fig and gs are defined
fig = plt.figure(figsize=(18, 12))  # Set size of combined chart
gs = GridSpec(2, 2, figure=fig, wspace=0.01, hspace=0.01)  # Define grid layout

# Ensure tech_colors are defined
tech_colors = {
    'charge': 'darkorchid', 'nuclear': 'tomato', 'coal': 'dimgrey',
    'hydro': 'deepskyblue', 'gas': 'violet', 'wind': 'limegreen',
    'solar': 'orange', 'stor': 'yellow', 'nse': 'crimson', 'Demand': '#000000'
}

# Ensure legend_ax is defined
legend_ax = fig.add_axes([0.85, 0.5, 0.1, 0.3])  # Adjust legend position
legend_ax.axis('off')  # Turn off axes

# Adjust font size of subplots
for i, scenario in enumerate(scenario_list):
    row, col = divmod(i, 2)  # Calculate subplot position
    ax = fig.add_subplot(gs[row, col])

    # Load image for each scenario
    img_path = base_path / f"Plot_Dispatch_{scenario}_week{week_number}.png"
    print(f"Attempting to read image file: {img_path}")
    if not img_path.exists():
        print(f"Error: File does not exist: {img_path}")
        continue
    img = plt.imread(img_path)
    print(f"Successfully read image file: {img_path}")
    ax.imshow(img)
    ax.axis('off')  # Turn off axes

    # Adjust font size of subplot titles
    ax.set_title(scenario, fontsize=30)  # Increase font size of subplot titles

# Ensure legend block height adjustment takes effect
handles = [plt.Line2D([0], [0], color=color, lw=10) for color in reversed(list(tech_colors.values())) if color != '#000000']  # Increase lw to adjust height
labels = [label.capitalize() for label in reversed(list(tech_colors.keys())) if label != 'Demand']
handles.insert(0, plt.Line2D([0], [0], color='black', linestyle='--', lw=10))  # Adjust height of Demand dashed line style
labels.insert(0, 'Demand')

# Regenerate legend
legend_ax.clear()  # Clear old legend
legend = legend_ax.legend(handles, labels, title="Tech", loc='center', fontsize=14, frameon=False)  # Adjust font size
legend.get_title().set_fontsize(16)
legend.get_title().set_ha('left')  # Align title to the left
