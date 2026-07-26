import numpy as np
from scipy.integrate import solve_ivp


def lorenz(t, state, sigma=10, rho=28, beta=8/3):
    x, y, z = state
    return [
        sigma * (y - x),
        x * (rho - z) - y,
        x * y - beta * z,
    ]


def rossler(t, state, a=0.2, b=0.2, c=5.7):
    x, y, z = state
    return [
        -(y + z),
        x + a * y,
        b + x * z - c * z,
    ]


def chua(t, state, alpha=15.6, beta=28.58, m0=-1.143, m1=-0.714):
    x, y, z = state
    fx = m1 * x + 0.5 * (m0 - m1) * (abs(x + 1) - abs(x - 1))
    return [
        alpha * (y - x - fx),
        x - y + z,
        -beta * y,
    ]


def chen(t, state, a=35, b=3, c=28):
    x, y, z = state
    return [
        a * (y - x),
        (c - a) * x + c * y - x * z,
        x * y - b * z,
    ]


def sprott_a(t, state):
    x, y, z = state
    return [
        y,
        -x + y * z,
        1 - y * y,
    ]


def halvorsen(t, state, a=1.89):
    x, y, z = state
    return [
        -a * x - 4 * y - 4 * z - y * y,
        -a * y - 4 * z - 4 * x - z * z,
        -a * z - 4 * x - 4 * y - x * x,
    ]


def aizawa(t, state, a=0.95, b=0.7, c=0.6, d=3.5, e=0.25, f=0.1):
    x, y, z = state
    return [
        (z - b) * x - d * y,
        d * x + (z - b) * y,
        c + a * z - z**3 / 3 - (x**2 + y**2) * (1 + e * z) + f * z * x**3,
    ]


def thomas(t, state, b=0.208186):
    x, y, z = state
    return [
        np.sin(y) - b * x,
        np.sin(z) - b * y,
        np.sin(x) - b * z,
    ]


def dadras(t, state, p=3, q=2.7, r=1.7, s=2, e=9):
    x, y, z = state
    return [
        y - p * x + q * y * z,
        r * y - x * z + z,
        s * x * y - e * z,
    ]


def lu_system(t, state, a=36, b=3, c=20):
    x, y, z = state
    return [
        a * (y - x),
        -x * z + c * y,
        x * y - b * z,
    ]


ATTRACTORS = {
    "lorenz": {
        "func": lorenz,
        "ic": [1.0, 1.0, 1.0],
        "t_span": (0, 100),
        "plot_axes": ("x", "z"),
        "var_names": ["x", "y", "z"],
    },
    "rossler": {
        "func": rossler,
        "ic": [1.0, 1.0, 0.0],
        "t_span": (0, 300),
        "plot_axes": ("x", "y"),
        "var_names": ["x", "y", "z"],
    },
    "chua": {
        "func": chua,
        "ic": [0.1, 0.0, 0.0],
        "t_span": (0, 100),
        "plot_axes": ("x", "y"),
        "var_names": ["x", "y", "z"],
    },
    "chen": {
        "func": chen,
        "ic": [-10.0, 0.0, 37.0],
        "t_span": (0, 50),
        "plot_axes": ("x", "z"),
        "var_names": ["x", "y", "z"],
    },
    "sprott_a": {
        "func": sprott_a,
        "ic": [0.1, 0.1, 0.1],
        "t_span": (0, 200),
        "plot_axes": ("x", "y"),
        "var_names": ["x", "y", "z"],
    },
    "halvorsen": {
        "func": halvorsen,
        "ic": [-5.0, 0.0, 0.0],
        "t_span": (0, 100),
        "plot_axes": ("x", "y"),
        "var_names": ["x", "y", "z"],
    },
    "aizawa": {
        "func": aizawa,
        "ic": [0.1, 0.0, 0.0],
        "t_span": (0, 200),
        "plot_axes": ("x", "y"),
        "var_names": ["x", "y", "z"],
    },
    "thomas": {
        "func": thomas,
        "ic": [1.0, 1.0, 1.0],
        "t_span": (0, 500),
        "plot_axes": ("x", "y"),
        "var_names": ["x", "y", "z"],
    },
    "dadras": {
        "func": dadras,
        "ic": [1.0, 1.0, 1.0],
        "t_span": (0, 50),
        "plot_axes": ("x", "y"),
        "var_names": ["x", "y", "z"],
    },
    "lu": {
        "func": lu_system,
        "ic": [0.1, 0.5, 0.6],
        "t_span": (0, 50),
        "plot_axes": ("x", "z"),
        "var_names": ["x", "y", "z"],
    },
}


def solve_attractor(name: str, max_step: float = 0.01) -> dict[str, np.ndarray]:
    info = ATTRACTORS[name]
    sol = solve_ivp(
        info["func"],
        info["t_span"],
        info["ic"],
        max_step=max_step,
        method="RK45",
        dense_output=False,
    )
    result = {"time": sol.t}
    for i, var_name in enumerate(info["var_names"]):
        result[var_name] = sol.y[i]
    return result
