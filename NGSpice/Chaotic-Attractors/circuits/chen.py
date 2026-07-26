from circuits.base import BaseCircuit
from src.registry import ModelRegistry


class ChenCircuit(BaseCircuit):
    NAME = "chen"
    DESCRIPTION = "Chen Attractor - Bushy Butterfly"
    PLOT_AXES = ("v(x)", "v(z)")

    def generate_netlist(self, registry: ModelRegistry) -> str:
        opamp = registry.get_opamp("LT1057")
        mult = registry.get_multiplier("AD633")
        inc_opamp = opamp.get_include()
        inc_mult = mult.get_include()

        # Chen: dx/dt=a(y-x), dy/dt=(c-a)x+cy-xz, dz/dt=xy-bz
        # a=35, b=3, c=28
        # Scaling: X=x/5, Y=y/5, Z=z/5 (ranges ~[-30,30] -> +/-6V)
        # dX/dt = 35*(Y-X)
        # dY/dt = (c-a)*X + c*Y - 5*XZ = -7X + 28Y - 5XZ
        # dZ/dt = 5*XY - 3Z
        # Mult: W_xz=XZ/10, W_xy=XY/10
        # 5XZ = 50*W_xz (gain 50 -> R=2k)
        # 5XY = 50*W_xy (gain 50 -> R=2k)
        # tau = 100k * 10nF = 1ms

        return f"""\
Chen Attractor - Analog Computer
*
{inc_opamp}
{inc_mult}
*
VCC vcc 0 15
VEE vee 0 -15
*
* === Integrator 1 (X): dX/dt = 35*(Y-X) = 35Y - 35X ===
* sum = -(35Y - 35X) = 35X - 35Y
* Feed X through 100k/35=2.857k, feed my through 2.857k
XU1 0 n1 vcc vee x {opamp.subckt_name}
C1 n1 x 10n
R1x x n1 2.857k
R1y my n1 2.857k
*
* === Integrator 2 (Y): dY/dt = -7X + 28Y - 5XZ ===
* sum = -(-7X + 28Y - 5XZ) = 7X - 28Y + 5XZ
* Feed X through 100k/7=14.3k (contributes 7X)
* Feed my through 100k/28=3.57k (contributes -(-Y)*28 = 28*(-my)... wait)
* my=-Y. Feed my through R -> contributes my*(100k/R) = -Y*(100k/R)
* Need -28Y in sum. Feed my through 100k/28=3.57k -> contributes -Y*28 = -28Y ✓ NO
* sum needs -28Y. my=-Y. Feeding my: contributes (-Y)*(G) where G=100k/R.
* For -28Y: (-Y)*28 = -28Y ✓ So feed my through 3.57k.
* Wait, I need +7X and -28Y and +5XZ.
* Feed X through 14.3k -> +7X ✓
* Feed my(=-Y) through 3.57k -> (-Y)*28 = -28Y ✓
* Feed w_xz(=XZ/10) through 2k -> (XZ/10)*50 = 5XZ ✓
XU2 0 n2 vcc vee y {opamp.subckt_name}
C2 n2 y 10n
R2x x n2 14.3k
R2y my n2 3.57k
R2m w_xz n2 2k
*
* === Integrator 3 (Z): dZ/dt = 5XY - 3Z ===
* sum = -(5XY - 3Z) = -5XY + 3Z
* Feed mw_xy(=-XY/10) through 2k -> (-XY/10)*50 = -5XY ✓
* Feed Z through 100k/3=33.3k -> Z*3 = 3Z ✓
XU3 0 n3 vcc vee z {opamp.subckt_name}
C3 n3 z 10n
R3m mw_xy n3 2k
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
.ic V(x)=-2.0 V(y)=0.0 V(z)=7.4
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
