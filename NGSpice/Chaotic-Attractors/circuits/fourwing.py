from circuits.base import BaseCircuit
from src.registry import ModelRegistry


class FourWingCircuit(BaseCircuit):
    NAME = "lu"
    DESCRIPTION = "Lu Attractor - Bridge Between Lorenz and Chen"
    PLOT_AXES = ("v(x)", "v(z)")

    def generate_netlist(self, registry: ModelRegistry) -> str:
        opamp = registry.get_opamp("LT1057")
        mult = registry.get_multiplier("AD633")
        inc_opamp = opamp.get_include()
        inc_mult = mult.get_include()

        # Lu: dx/dt=a(y-x), dy/dt=-xz+cy, dz/dt=xy-bz
        # a=36, b=3, c=20
        # Scaling: X=x/4, Y=y/4, Z=z/5 (x,y~[-22,22], z~[5,40])
        # dX/dt = (1/4)*36*(4Y-4X) = 36*(Y-X)
        # dY/dt = (1/4)*(-4X*5Z + 20*4Y) = -5XZ + 20Y
        # dZ/dt = (1/5)*(4X*4Y - 3*5Z) = 16XY/5 - 3Z = 3.2XY - 3Z
        # Mult W_xz = X*Z/10. Need 5XZ = 50*W_xz (gain 50 -> R=2k)
        # Mult W_xy = X*Y/10. Need 3.2XY = 32*W_xy (gain 32 -> R=3.125k)
        # tau = 100k * 10nF = 1ms

        return f"""\
Lu Attractor - Analog Computer
*
{inc_opamp}
{inc_mult}
*
VCC vcc 0 15
VEE vee 0 -15
*
* === Integrator 1 (X): dX/dt = 36*(Y-X) = 36Y - 36X ===
* sum = -(36Y - 36X) = 36X - 36Y
* Feed X through 100k/36=2.78k: contributes 36X ✓
* Feed my(=-Y) through 2.78k: contributes (-Y)*36 = -36Y ✓
XU1 0 n1 vcc vee x {opamp.subckt_name}
C1 n1 x 10n
R1x x n1 2.78k
R1y my n1 2.78k
*
* === Integrator 2 (Y): dY/dt = -5XZ + 20Y ===
* sum = -(-5XZ + 20Y) = 5XZ - 20Y
* Feed w_xz(=XZ/10) through 2k (gain 50): contributes (XZ/10)*50 = 5XZ ✓
* Feed my(=-Y) through 100k/20=5k: contributes (-Y)*20 = -20Y ✓
XU2 0 n2 vcc vee y {opamp.subckt_name}
C2 n2 y 10n
R2m w_xz n2 2k
R2y my n2 5k
*
* === Integrator 3 (Z): dZ/dt = 3.2XY - 3Z ===
* sum = -(3.2XY - 3Z) = -3.2XY + 3Z
* Feed mw_xy(=-XY/10) through 100k/32=3.125k: contributes (-XY/10)*32 = -3.2XY ✓
* Feed Z through 100k/3=33.3k: contributes Z*3 = 3Z ✓
XU3 0 n3 vcc vee z {opamp.subckt_name}
C3 n3 z 10n
R3m mw_xy n3 3.125k
R3z z n3 33.3k
*
* === Multipliers ===
XM1 x 0 z 0 0 w_xz vcc vee {mult.subckt_name}
XM2 x 0 y 0 0 w_xy vcc vee {mult.subckt_name}
* mw_xy = -XY/10
XU7 0 n7 vcc vee mw_xy {opamp.subckt_name}
R7a w_xy n7 10k
R7b n7 mw_xy 10k
*
* === Inverters ===
XU4 0 n4 vcc vee mx {opamp.subckt_name}
R4a x n4 10k
R4b n4 mx 10k
XU5 0 n5 vcc vee my {opamp.subckt_name}
R5a y n5 10k
R5b n5 my 10k
*
.ic V(x)=0.025 V(y)=0.125 V(z)=0.12
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
        return ("v(x)", "v(z)")
