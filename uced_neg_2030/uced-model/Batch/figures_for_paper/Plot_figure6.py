import os
from pathlib import Path
from itertools import product

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import MultipleLocator, FuncFormatter


# =========================
# 1. Define scenario dimensions
# =========================
weatheryears = ["weather202207"]
deratepercents = ["derate7.5pct"]
loadgrowths = ["growth1", "growth2", "growth3"]
markets = ["PriorityMLT", "MLT", "SpotMLT"]

BASE_PREFIX = "../Results_ne_203007_"
SCRIPT_DIR = Path(__file__).resolve().parent


# =========================
# 2. Data reading functions
# =========================
def read_region_series_for_scenario(scenario_dir: Path, region_idx: int) -> np.ndarray:
    weekly_series = []

    for week in range(1, 5):
        week_dir = scenario_dir / str(week)
        csv_path = week_dir / f"vNSE{region_idx}.csv"

        if not csv_path.exists():
            raise FileNotFoundError(f"File not found: {csv_path}")

        df = pd.read_csv(csv_path)
        data_row = df.iloc[0, 1:]
        data_values = data_row.to_numpy(dtype=float)

        if data_values.size != 168:
            raise ValueError(f"{csv_path} has {data_values.size} hours instead of 168")

        weekly_series.append(data_values)

    return np.concatenate(weekly_series, axis=0)  # 672 hours


def compute_max_system_nse_for_scenario(
    scenario_dir: Path,
) -> tuple[float, int, np.ndarray, np.ndarray]:
    region_series_list = []

    for region_idx in range(1, 7):
        series = read_region_series_for_scenario(scenario_dir, region_idx)
        region_series_list.append(series)

    all_regions = np.vstack(region_series_list)
    system_series = all_regions.sum(axis=0)

    max_idx = int(system_series.argmax())
    max_hour_index = max_idx + 1
    max_nse = float(system_series[max_idx])

    return max_nse, max_hour_index, system_series, all_regions


# =========================
# 3. Grouping utilities
# =========================
def build_groups(result_df: pd.DataFrame) -> dict[str, list[float]]:
    """
    Each group keeps market order:
    growthX -> [PriorityMLT, MLT, SpotMLT]
    Missing scenario -> np.nan
    """
    groups = {}

    for lg in loadgrowths:
        values = []
        for mk in markets:
            sub = result_df[
                (result_df["loadgrowth"] == lg) &
                (result_df["market"] == mk)
            ]
            if sub.empty:
                values.append(np.nan)
            else:
                values.append(float(sub["max_system_nse"].iloc[0]))
        groups[lg] = values

    return groups


def print_groups(groups: dict[str, list[float]]):
    for i, lg in enumerate(loadgrowths, start=1):
        print(f"\nGroup{i} (loadgrowth = {lg})")
        for mk, val in zip(markets, groups[lg]):
            if np.isnan(val):
                print(f"  {mk}: NaN (missing scenario)")
            else:
                print(f"  {mk}: {val:,.0f}")  # Display with thousand separator


# =========================
# 4. Plotting
# =========================
def plot_groups(groups: dict[str, list[float]]):
    labels = [
        "Annual load growth rate 4.44%",
        "Annual load growth rate 5.02%",
        "Annual load growth rate 5.59%",
    ]

    group_vals = [groups[lg] for lg in loadgrowths]

    bar_width = 0.4
    x = np.array([-0.5, 0.0, 0.5])
    group_spacing = 1.9

    plt.figure(figsize=(10, 3.5))

    all_vals = [v for g in group_vals for v in g if not np.isnan(v)]
    if all_vals:
        y_min = min(all_vals)
        y_max = max(all_vals)
        span = max(y_max - y_min, abs(y_max) * 0.1)
        label_y = y_min - 0.04 * span
    else:
        label_y = -1.0

    for i, (lab, g) in enumerate(zip(labels, group_vals)):
        pos = x + i * group_spacing
        plt.bar(pos, g, width=bar_width)

        if i < len(group_vals) - 1:
            plt.axvline(
                x=i * group_spacing + 0.9,
                color="#303030",
                linestyle="--",
                ymin=-0.10,
                ymax=1.11,
                alpha=0.7,
                clip_on=False,
            )

        for j, mk in enumerate(markets):
            plt.text(pos[j], label_y, mk, ha="center", va="top", fontsize=12)

    x_min = -0.9
    x_max = (len(group_vals) - 1) * group_spacing + 0.9
    plt.xlim(x_min, x_max)

    plt.axvline(
        x=x_min,
        color="#555555",
        lw=1.2,
        ymin=-0.08,
        ymax=1.09,
        clip_on=False,
    )
    plt.axvline(
        x=x_max,
        color="#555555",
        lw=1.2,
        ymin=-0.08,
        ymax=1.09,
        clip_on=False,
    )

    ax = plt.gca()
    ylim_max = ax.get_ylim()[1]

    for i, lab in enumerate(labels):
        plt.text(i * group_spacing, ylim_max * 1.04, lab,
                 ha="center", fontsize=12)

    plt.tick_params(axis="x", bottom=False, labelbottom=False)
    ax.spines["left"].set_visible(False)
    ax.spines["right"].set_visible(False)

    plt.ylabel("Maximum NSE (MWh)", fontsize=12)

    # =========================
    # y-axis ticks: 2000 step + thousand separator
    # =========================
    ax.yaxis.set_major_locator(MultipleLocator(2000))
    ax.yaxis.set_major_formatter(
        FuncFormatter(lambda x, pos: f"{int(x):,}")
    )
    ax.set_ylim(bottom=0)

    plt.subplots_adjust(bottom=0.35)
    plt.tight_layout()

    # ---- Save figure ----
    out_path = SCRIPT_DIR / "figure6_max_nse_barchart_allProvinces.png"
    plt.savefig(out_path, dpi=300, bbox_inches="tight")
    print(f"\nFigure saved to: {out_path}")

    plt.show()


# =========================
# 5. Main
# =========================
def main():
    records = []

    temp_dir = SCRIPT_DIR / "temp"
    temp_dir.mkdir(exist_ok=True)

    for weatheryear, deratepercent, loadgrowth, market in product(
        weatheryears, deratepercents, loadgrowths, markets
    ):
        scenario_name = f"{market}_{loadgrowth}_{deratepercent}_{weatheryear}"
        scenario_dir = Path(f"{BASE_PREFIX}{scenario_name}")

        if not scenario_dir.exists():
            print(f"Warning: scenario directory does not exist, skip: {scenario_dir}")
            continue

        try:
            max_nse, max_hour_index, system_series, all_regions = \
                compute_max_system_nse_for_scenario(scenario_dir)
        except (FileNotFoundError, ValueError) as e:
            print(f"Error in scenario {scenario_name}: {e}")
            continue

        # Save hourly time series CSV
        hours = np.arange(1, system_series.size + 1)
        csv_data = {"hour_index": hours}
        for r in range(all_regions.shape[0]):
            csv_data[f"NSE_region{r + 1}"] = all_regions[r, :]
        csv_data["NSE_system"] = system_series

        pd.DataFrame(csv_data).to_csv(
            temp_dir / f"{weatheryear}_{deratepercent}_{loadgrowth}_{market}_NSE_timeseries.csv",
            index=False,
        )

        records.append(
            dict(
                scenario=scenario_name,
                market=market,
                loadgrowth=loadgrowth,
                deratepercent=deratepercent,
                weatheryear=weatheryear,
                max_system_nse=max_nse,
                max_hour_index=max_hour_index,
            )
        )

    if not records:
        print("No valid scenarios found.")
        return

    result_df = pd.DataFrame(records)

    groups = build_groups(result_df)
    print_groups(groups)
    plot_groups(groups)


if __name__ == "__main__":
    main()