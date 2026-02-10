import os
from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import PercentFormatter
from matplotlib.lines import Line2D

# -----------------------
# Basic path setup
# -----------------------
parent_dir = Path.cwd().parent

PriorityMLT = parent_dir / 'Results_ne_2021_PriorityMLT' / 'curtailmentsummary_RES.csv'
MLT = parent_dir / 'Results_ne_2021_MLT' / 'curtailmentsummary_RES.csv'
SpotMLT = parent_dir / 'Results_ne_2021_SpotMLT' / 'curtailmentsummary_RES.csv'
FlexibleSpotMLT = parent_dir / 'Results_ne_2021_FlexibleSpotMLT' / 'curtailmentsummary_RES.csv'

results_paths = [
    PriorityMLT,
    MLT,
    SpotMLT,
    FlexibleSpotMLT
]

# Title mapping
title_map = {
    'Results_ne_2021_PriorityMLT': 'PriorityMLT',
    'Results_ne_2021_MLT': 'MLT',
    'Results_ne_2021_SpotMLT': 'SpotMLT',
    'Results_ne_2021_FlexibleSpotMLT': 'FlexibleSpotMLT'
}

# Regions to plot (fixed order)
keep_regions = ['HL', 'IME', 'JL', 'LN']

# Region color mapping
region_colors = {
    'HL': 'red',
    'IME': 'blue',
    'JL': 'lime',
    'LN': 'orange'
}

# -----------------------
# 单图绘制函数
# -----------------------
def plot_curtailment(ax, csv_path):

    df = pd.read_csv(csv_path)

    # Keep only target four regions (prevent JB/SD from entering legend)
    df = df[df['Region'].isin(keep_regions)].copy()

    # Columns starting with Week (used for dropna etc.)
    week_cols = [c for c in df.columns if c.startswith('Week')]

    # Drop rows where all Week values are NaN for target regions as a safeguard
    if week_cols:
        df = df.dropna(subset=week_cols, how='all')

    # Fix tiny negatives (-1e-6 to 0 becomes 0)
    numeric_cols = df.select_dtypes(include='number').columns
    for col in numeric_cols:
        mask = (df[col] > -1e-6) & (df[col] < 0)
        df.loc[mask, col] = 0

    # Convert wide table to long format
    long_df = df.melt(
        id_vars='Region',
        var_name='Week',
        value_name='Curtailment'
    )

    # Convert Week to 1,2,3,...
    week_cat = pd.Categorical(
        long_df['Week'],
        categories=long_df['Week'].unique(),
        ordered=True
    )
    long_df['Week_num'] = week_cat.codes + 1

    # Title
    parent_name = Path(csv_path).parent.name
    title_text = title_map.get(parent_name, 'Unknown')

    # Plot lines in fixed order to keep legend consistent
    for region in keep_regions:
        sub = long_df[long_df['Region'] == region]
        if sub.empty:
            continue
        ax.plot(
            sub['Week_num'],
            sub['Curtailment'],
            label=region,
            linewidth=2.3,
            color=region_colors[region]
        )

    # Axis settings
    ax.set_title(title_text, fontsize=20, y=0.85)
    ax.set_ylabel('Curtailment Rate', fontsize=11)

    ax.set_xlim(1, 12)
    ax.set_xticks(range(1, 13))

    ax.set_ylim(0, 0.20)
    ax.set_yticks([0.0, 0.1, 0.2])
    ax.yaxis.set_major_formatter(
        PercentFormatter(xmax=1.0, decimals=0)
    )

    ax.grid(False)

    # Axis spine style
    for spine in ax.spines.values():
        spine.set_color('grey')

    for spine_name, spine in ax.spines.items():
        if spine_name in ['left', 'bottom']:
            spine.set_visible(True)
        else:
            spine.set_visible(False)

    ax.tick_params(axis='x', labelsize=14, length=5, width=1)
    ax.tick_params(axis='y', labelsize=14, length=5, width=1)


# -----------------------
# Main plot
# -----------------------
fig, axes = plt.subplots(
    nrows=4,
    ncols=1,
    sharex=True,
    figsize=(10, 8)
)

for ax, path in zip(axes, results_paths):
    plot_curtailment(ax, path)
    if ax == axes[-1]:
        ax.set_xlabel('Week', fontsize=12)
    ax.set_title(ax.get_title(), fontsize=16, y=0.8)

# -----------------------
# Unified legend (title + color blocks on same row)
# -----------------------
# Remove individual subplot legends if present
for ax in axes:
    leg = ax.get_legend()
    if leg is not None:
        leg.remove()

# Build legend manually using keep_regions order
title_handle = Line2D([], [], linestyle='none', marker=None)

region_handles = [
    Line2D([0], [0], color=region_colors[r], linewidth=4)
    for r in keep_regions
]

handles2 = [title_handle] + region_handles
labels2 = ['Province:'] + keep_regions

legend = fig.legend(
    handles2,
    labels2,
    loc='lower center',
    ncol=len(labels2),
    frameon=False,
    bbox_to_anchor=(0.5, -0.013),
    columnspacing=2.0,
    handlelength=1.5,
    handletextpad=0.5
)

# Legend title styling
legend.legend_handles[0].set_visible(False)
legend.get_texts()[0].set_fontweight('normal')

# Legend font size
for text in legend.get_texts():
    text.set_fontsize(12)

# -----------------------
# Layout and save
# -----------------------
plt.subplots_adjust(
    top=0.95,
    bottom=0.12,
    hspace=0.5
)

output_file = 'figure3.jpeg'
fig.savefig(
    output_file,
    dpi=300,
    facecolor='white',
    bbox_inches='tight'
)

plt.show()