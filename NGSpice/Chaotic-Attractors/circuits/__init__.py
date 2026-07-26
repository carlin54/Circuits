from circuits.chua import ChuaCircuit

ALL_CIRCUITS = [ChuaCircuit]

_LAZY_IMPORTS = {
    "rossler": ("circuits.rossler", "RosslerCircuit"),
    "lorenz": ("circuits.lorenz", "LorenzCircuit"),
    "chen": ("circuits.chen", "ChenCircuit"),
    "sprott_a": ("circuits.sprott", "SprottCircuit"),
    "halvorsen": ("circuits.halvorsen", "HalvorsenCircuit"),
    "aizawa": ("circuits.aizawa", "AizawaCircuit"),
    "thomas": ("circuits.thomas", "ThomasCircuit"),
    "dadras": ("circuits.dadras", "DadrasCircuit"),
    "lu": ("circuits.fourwing", "FourWingCircuit"),
}


def get_circuit(name: str):
    for cls in ALL_CIRCUITS:
        if cls.NAME == name:
            return cls
    if name in _LAZY_IMPORTS:
        module_path, class_name = _LAZY_IMPORTS[name]
        import importlib
        mod = importlib.import_module(module_path)
        cls = getattr(mod, class_name)
        ALL_CIRCUITS.append(cls)
        return cls
    raise KeyError(f"Unknown circuit: {name}")


def load_all():
    for name in list(_LAZY_IMPORTS.keys()):
        try:
            get_circuit(name)
        except (ImportError, NotImplementedError):
            pass
    return ALL_CIRCUITS
