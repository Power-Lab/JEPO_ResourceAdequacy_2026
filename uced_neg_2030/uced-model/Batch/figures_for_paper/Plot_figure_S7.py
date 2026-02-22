from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.ticker import MultipleLocator, FuncFormatter


# 1. Define scenario dimensions
weatheryears = ["weather202207"]
deratepercents = ["derate7.5pct"]
loadgrowths = ["growth1", "growth2", "growth3"]
markets = ["PriorityMLT", "MLT", "SpotMLT"]

SCRIPT_DIR = Path(__file__).resolve().parent

def print_groups(groups: dict[str, list[float]]):
    for i, lg in enumerate(loadgrowths, start=1):
        print(f"\nGroup{i} (loadgrowth = {lg})")
        for mk, val in zip(markets, groups[lg]):
            if np.isnan(val):
                print(f"  {mk}: NaN (missing scenario)")
            else:
                print(f"  {mk}: {val:,.0f}")  # Display with thousand separator


# 3. Plotting
def plot_groups(groups: dict[str, list[float]], out_filename: str):
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
    out_path = SCRIPT_DIR / out_filename
    plt.savefig(out_path, format='pdf', bbox_inches="tight")
    print(f"\nFigure saved to: {out_path}")

    #plt.show()

# 4. NSE 
GROUP_VALUES_7P5 = {
    "growth1": [136, 136, 107],
    "growth2": [294, 260, 94],
    "growth3": [6929, 3617, 36],
}

GROUP_VALUES_10 = {
    "growth1": [6718, 2229, 0],
    "growth2": [7882, 7750, 0],
    "growth3": [8654, 8605, 0],
}

# 5. Main
def main():
    cases = [
        ("Derate 7.5%", GROUP_VALUES_7P5, "figure_SI7(1).pdf"),
        ("Derate 10%", GROUP_VALUES_10, "figure_SI7(2).pdf"),
    ]

    for label, groups, outfile in cases:
        print(f"\n=== {label} ===")
        print_groups(groups)
        plot_groups(groups, out_filename=outfile)


if __name__ == "__main__":
    main()