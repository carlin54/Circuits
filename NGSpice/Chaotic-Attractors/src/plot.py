from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


def plot_phase_space(
    data: dict[str, np.ndarray],
    x_var: str,
    y_var: str,
    title: str,
    output_path: Path,
    reference_data: dict[str, np.ndarray] | None = None,
    skip_fraction: float = 0.1,
):
    if reference_data is not None:
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
    else:
        fig, ax1 = plt.subplots(1, 1, figsize=(7, 6))
        ax2 = None

    fig.patch.set_facecolor("#1a1a2e")

    x = data[x_var]
    y = data[y_var]
    skip = int(len(x) * skip_fraction)
    x, y = x[skip:], y[skip:]

    _draw_attractor(ax1, x, y, x_var, y_var, f"{title} (ngspice)")

    if ax2 is not None and reference_data is not None:
        rx = reference_data[x_var]
        ry = reference_data[y_var]
        skip_r = int(len(rx) * skip_fraction)
        rx, ry = rx[skip_r:], ry[skip_r:]
        _draw_attractor(ax2, rx, ry, x_var, y_var, f"{title} (scipy reference)")

    plt.tight_layout()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(output_path, dpi=150, facecolor=fig.get_facecolor())
    plt.close()


def _draw_attractor(ax, x, y, x_label, y_label, title):
    ax.set_facecolor("#0f0f23")
    t = np.linspace(0, 1, len(x))
    colors = plt.cm.plasma(t)
    for i in range(len(x) - 1):
        ax.plot(
            x[i:i+2], y[i:i+2],
            color=colors[i],
            linewidth=0.3,
            alpha=0.8,
        )
    ax.set_xlabel(x_label, color="white")
    ax.set_ylabel(y_label, color="white")
    ax.set_title(title, color="white", fontsize=11)
    ax.tick_params(colors="white")
    for spine in ax.spines.values():
        spine.set_color("#333355")
    ax.set_aspect("equal", adjustable="datalim")
