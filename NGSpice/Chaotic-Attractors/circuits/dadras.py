from circuits.base import BaseCircuit
from src.registry import ModelRegistry


class DadrasCircuit(BaseCircuit):
    NAME = "dadras"
    DESCRIPTION = "Dadras Attractor - Dense Layered Butterfly"
    PLOT_AXES = ("v(x)", "v(y)")

    def generate_netlist(self, registry: ModelRegistry) -> str:
        opamp = registry.get_opamp("LT1057")
        mult = registry.get_multiplier("AD633")
        inc_opamp = opamp.get_include()
        inc_mult = mult.get_include()

        # Dadras: dx/dt=y-px+qyz, dy/dt=ry-xz+z, dz/dt=sxy-ez
        # p=3, q=2.7, r=1.7, s=2, e=9
        # Ranges: x~[-5,5], y~[-5,5], z~[-3,3]. No scaling needed.
        # tau = 100k * 10nF = 1ms
        # Multipliers: W_yz=YZ/10, W_xz=XZ/10, W_xy=XY/10

        return f"""\
Dadras Attractor - Analog Computer
*
{inc_opamp}
{inc_mult}
*
VCC vcc 0 15
VEE vee 0 -15
*
* === Integrator 1 (X): dX/dt = Y - 3X + 2.7YZ ===
* sum = -(Y - 3X + 2.7YZ) = -Y + 3X - 2.7YZ
* Feed my(=-Y) through 100k (gain 1): contributes -Y ✓
* Feed X through 100k/3=33.3k (gain 3): contributes 3X ✓
* Feed mw_yz(=-YZ/10) through 100k/27=3.7k (gain 27): contributes -YZ/10*27=-2.7YZ ✓
XU1 0 n1 vcc vee x {opamp.subckt_name}
C1 n1 x 10n
R1y my n1 100k
R1x x n1 33.3k
R1m mw_yz n1 3.7k
*
* === Integrator 2 (Y): dY/dt = 1.7Y - XZ + Z ===
* sum = -(1.7Y - XZ + Z) = -1.7Y + XZ - Z
* Feed my through 100k/1.7=58.8k: contributes (-Y)*1.7=-1.7Y ✓
* Feed w_xz(=XZ/10) through 10k (gain 10): contributes XZ/10*10=XZ ✓
* Feed mz(=-Z) through 100k: contributes -Z ✓
XU2 0 n2 vcc vee y {opamp.subckt_name}
C2 n2 y 10n
R2y my n2 58.8k
R2m w_xz n2 10k
R2z mz n2 100k
*
* === Integrator 3 (Z): dZ/dt = 2XY - 9Z ===
* sum = -(2XY - 9Z) = -2XY + 9Z
* Feed mw_xy(=-XY/10) through 100k/20=5k (gain 20): contributes -XY/10*20=-2XY ✓
* Feed Z through 100k/9=11.1k (gain 9): contributes 9Z ✓
XU3 0 n3 vcc vee z {opamp.subckt_name}
C3 n3 z 10n
R3m mw_xy n3 5k
R3z z n3 11.1k
*
* === Multipliers ===
XM1 y 0 z 0 0 w_yz vcc vee {mult.subckt_name}
XM2 x 0 z 0 0 w_xz vcc vee {mult.subckt_name}
XM3 x 0 y 0 0 w_xy vcc vee {mult.subckt_name}
*
* === Inverters ===
XU4 0 n4 vcc vee mx {opamp.subckt_name}
R4a x n4 10k
R4b n4 mx 10k
XU5 0 n5 vcc vee my {opamp.subckt_name}
R5a y n5 10k
R5b n5 my 10k
XU6 0 n6 vcc vee mz {opamp.subckt_name}
R6a z n6 10k
R6b n6 mz 10k
XU7 0 n7 vcc vee mw_yz {opamp.subckt_name}
R7a w_yz n7 10k
R7b n7 mw_yz 10k
XU8 0 n8 vcc vee mw_xy {opamp.subckt_name}
R8a w_xy n8 10k
R8b n8 mw_xy 10k
*
.ic V(x)=1.0 V(y)=1.0 V(z)=1.0
*
.tran 10u 60m 5m uic
.options method=gear
.options reltol=1e-3
.options abstol=1e-7
.options vntol=1e-4
.options itl4=500
*
.end
"""

    def get_plot_variables(self) -> tuple[str, str]:
        return ("v(x)", "v(y)")
