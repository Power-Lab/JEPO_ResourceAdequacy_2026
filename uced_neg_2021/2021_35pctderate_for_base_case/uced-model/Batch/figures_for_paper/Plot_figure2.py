import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import os

base_dir = "../"
folders = [
    "Results_ne_2021_PriorityMLT",
    "Results_ne_2021_MLT",
    "Results_ne_2021_SpotMLT",
    "Results_ne_2021_FlexibleSpotMLT",
]
zones = [
    "Zone 1 Max NSE MW",
    "Zone 2 Max NSE MW",
    "Zone 3 Max NSE MW",
    "Zone 4 Max NSE MW",
    "Zone 5 Max NSE MW",
    "Zone 6 Max NSE MW",
]
bold_contrast_colors = ["red", "blue", "lime", "orange", "purple", "yellow"]
legend_labels = ["HL", "IME", "JL", "LN", "SD", "JB"]

offset = (3.75 * np.pi) / 180
angle_shift = offset
fig, ax = plt.subplots(figsize=(8, 8), subplot_kw=dict(polar=True))

angle_ranges = [
    0 + offset,
    np.pi / 2 + offset,
    np.pi + offset,
    3 * np.pi / 2 + offset,
    2 * np.pi + offset,
]
width = (2 * np.pi / 4) - 0.1

all_angles = []
max_values = 0

# Pass 1: get global max
for folder in folders:
    file_path = os.path.join(base_dir, folder, "nsesummary.csv")
    df_tmp = pd.read_csv(file_path)
    total_values = df_tmp[zones].sum(axis=1).max()
    max_values = max(max_values, total_values)

# Radius with a small padding so the outer ring slightly exceeds the tallest stack
pad_ratio = 0.01
rmax = max_values * (1 + pad_ratio)
ax.set_ylim(0, rmax)

# Pass 2: plot
for i, folder in enumerate(folders):
    file_path = os.path.join(base_dir, folder, "nsesummary.csv")
    df = pd.read_csv(file_path)

    angles = np.linspace(angle_ranges[i], angle_ranges[i + 1], len(df["Week"]), endpoint=False).tolist()
    angles += angles[:1]
    all_angles.extend(angles[:-1])

    bottom = np.zeros(len(df["Week"]))
    for idx, zone in enumerate(zones):
        values = df[zone].values
        ax.bar(
            angles[:-1],
            values,
            width=width / len(df["Week"]),
            bottom=bottom,
            color=bold_contrast_colors[idx],
            edgecolor=None,
            alpha=0.7,
            label=legend_labels[idx] if i == 0 else None,
        )
        bottom += values

    # Week labels outside the outer ring
    for j, angle in enumerate(angles[:-1]):
        ax.text(
            angle,
            rmax * 1.04,
            f"{df['Week'][j]}",
            ha="center",
            va="center",
            fontsize=10,
            color="black",
            clip_on=False,
        )

ax.set_theta_offset(-np.pi)
ax.set_theta_direction(-1)
ax.xaxis.set_visible(False)
# Remove the outer circular frame
ax.spines["polar"].set_visible(False)

label_positions = np.linspace(0, 2 * np.pi, 4, endpoint=False) + np.pi / 4
ax.text(label_positions[0], rmax * 1.09, "PriorityMLT", ha="center", va="center", fontsize=14, rotation=45, clip_on=False)
ax.text(label_positions[1], rmax * 1.09, "MLT", ha="center", va="center", fontsize=14, rotation=-45, clip_on=False)
ax.text(label_positions[2], rmax * 1.09, "SpotMLT", ha="center", va="center", fontsize=14, rotation=-135, clip_on=False)
ax.text(label_positions[3], rmax * 1.09, "FlexibleSpotMLT", ha="center", va="center", fontsize=14, rotation=135, clip_on=False)

ax.set_rlabel_position(310)
ax.tick_params(axis="y", labelsize=12)
# Radial grid: 2000 steps inside, but drop the top 2000-multiple ring; outermost ring only rmax
inner_limit = max(rmax - 0, 0)
yticks_inner = np.arange(0, inner_limit + 1e-9, 2000)
yticks = np.append(yticks_inner, rmax)
ax.set_yticks(yticks)
labels = [f"{t:.0f}" for t in yticks_inner] + [""]
ax.set_yticklabels(labels)

for angle in all_angles:
    ax.plot([angle + angle_shift, angle + angle_shift], [0, rmax], color="gray", linewidth=0.3, alpha=0.3)
for angle in [0, np.pi / 2, np.pi, 3 * np.pi / 2]:
    ax.plot([angle, angle], [0, rmax], color="black", linewidth=1.1, alpha=1)

ax.legend(loc="upper right", bbox_to_anchor=(1.2, 1), title="Province", fontsize=10, title_fontsize=12, frameon=False)

output_path = "figure2.png"
plt.savefig(output_path, dpi=300, bbox_inches="tight")
plt.show()