import matplotlib.pyplot as plt
import numpy as np

# Chart configuration
bar_width = 0.15
space_between = 0.06
province_spacing = 0.12

provinces = ['HL', 'JL', 'LN']
priority_mlt = np.array([72, 61, 165])
mlt = np.array([72, 61, 165])
spot_mlt = np.array([92, 82, 153])
flexible_spot_mlt = np.array([44, 53, 185])
real_gen_total = np.array([80, 65, 165])  #historical

ind = np.arange(len(provinces))
ind_group = ind - 1.5 * (bar_width + space_between) + province_spacing * ind

fig, ax = plt.subplots(figsize=(9, 5.9))

# Plotting bars with Nature-like colors
ax.bar(ind_group, priority_mlt, width=bar_width, label='PriorityMLT', color='#377eb8')  # Blue
ax.bar(ind_group + 1*(bar_width + space_between), mlt, width=bar_width, label='MLT', color='#ff7f00')  # Orange
ax.bar(ind_group + 2*(bar_width + space_between), spot_mlt, width=bar_width, label='SpotMLT', color='#4daf4a')  # Green
ax.bar(ind_group + 3*(bar_width + space_between), flexible_spot_mlt, width=bar_width, label='FlexibleSpotMLT', color='#984ea3')  # Purple

# Adding dashed lines for historical generation
shift = bar_width / 2
for i in range(len(provinces)):
    left_edge = ind_group[i] - shift
    right_edge = ind_group[i] + 3 * (bar_width + space_between) + shift
    ax.hlines(y=real_gen_total[i], xmin=left_edge, xmax=right_edge, colors='#525252', linestyles=':', linewidth=1.5)  # DarkGray

# Removing top and right spines
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

# Removing existing x-axis ticks
ax.set_xticks([])

# Drawing vertical lines and adding x-axis ticks
new_xticks = []
new_xticklabels = []
for i in range(len(provinces) - 1):
    right_edge = ind_group[i] + 3 * (bar_width + space_between) + bar_width
    gap = ind_group[i + 1] - right_edge
    x_position = right_edge + 0.3 * gap  # move divider right toward next group
    new_xticks.append(x_position)
    ax.axvline(x=x_position, color='lightgray', linestyle='-', linewidth=1)
    ax.annotate('|', xy=(x_position, 0), xycoords=('data', 'axes fraction'), xytext=(0, 0),
                textcoords='offset points', ha='center', va='top', color='lightgray', fontsize=20)

# Adding title and labels
ax.set_xlabel('Province')
ax.set_ylabel('Total Generation (GWh)')
ax.yaxis.set_label_coords(-0.06, 0.508)

# Setting new x-axis ticks for the provinces
new_xticks = ind + province_spacing * ind
ax.set_xticks(new_xticks)
ax.set_xticklabels(provinces)

# Customizing the color of the internal ticks and labels
for tick in ax.get_xticklines():
    tick.set_color('white')
ax.tick_params(axis='x', which='both', color='white')
for label in ax.get_xticklabels():
    label.set_color('black')

# Adjusting legend position
historic_handle = plt.Line2D([0], [0], color='#525252', linestyle=':', linewidth=1.5, label='Historical generation')
handles, labels = ax.get_legend_handles_labels()
handles = [historic_handle] + handles
labels = ['Historical generation'] + labels
ax.legend(
    handles,
    labels,
    loc='upper left',
    bbox_to_anchor=(0.00, 1),
    ncol=1,
    handlelength=2.5,
    handletextpad=0.9,
    borderpad=0.8,
)

# Saving the chart
plt.savefig('figure_SI3.pdf')
