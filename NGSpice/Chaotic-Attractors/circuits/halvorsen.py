from circuits.base import BaseCircuit
from src.registry import ModelRegistry


class HalvorsenCircuit(BaseCircuit):
    NAME = "halvorsen"
    DESCRIPTION = "Halvorsen Attractor - Three-Lobed Pinwheel"
    PLOT_AXES = ("v(x)", "v(y)")

    def generate_netlist(self, registry: ModelRegistry) -> str:
        opamp = registry.get_opamp("LT1057")
        mult = registry.get_multiplier("AD633")
        inc_opamp = opamp.get_include()
        inc_mult = mult.get_include()

        # Halvorsen: dx/dt=-ax-4y-4z-y^2, dy/dt=-ay-4z-4x-z^2, dz/dt=-az-4x-4y-x^2
        # a=1.89. Ranges: ~[-10,10] for all. Scale by 0.5: X=x/2 etc.
        # dX/dt = (1/2)*(-1.89*2X - 4*2Y - 4*2Z - (2Y)^2)
        #       = -1.89X - 4Y - 4Z - 2Y^2
        # Mult: W_y2 = Y*Y/10. Need 2Y^2 = 20*W_y2 (gain 20 -> R=5k)
        # Similarly for other squares.
        # tau = 100k * 10nF = 1ms

        return f"""\
Halvorsen Attractor - Analog Computer
*
{inc_opamp}
{inc_mult}
*
VCC vcc 0 15
VEE vee 0 -15
*
* Scaling: X=x/2, Y=y/2, Z=z/2
* dX/dt = -1.89X - 4Y - 4Z - 2Y^2
* dY/dt = -1.89Y - 4Z - 4X - 2Z^2
* dZ/dt = -1.89Z - 4X - 4Y - 2X^2
*
* === Integrator 1 (X): dX/dt = -1.89X - 4Y - 4Z - 2Y^2 ===
* sum = 1.89X + 4Y + 4Z + 2Y^2
* Feed X through 100k/1.89=52.9k
* Feed Y through 100k/4=25k
* Feed Z through 25k
* Feed w_y2(=Y^2/10) through 100k/20=5k
XU1 0 n1 vcc vee x {opamp.subckt_name}
C1 n1 x 10n
R1x x n1 52.9k
R1y y n1 25k
R1z z n1 25k
R1m w_y2 n1 5k
*
* === Integrator 2 (Y): dY/dt = -1.89Y - 4Z - 4X - 2Z^2 ===
* sum = 1.89Y + 4Z + 4X + 2Z^2
XU2 0 n2 vcc vee y {opamp.subckt_name}
C2 n2 y 10n
R2y y n2 52.9k
R2z z n2 25k
R2x x n2 25k
R2m w_z2 n2 5k
*
* === Integrator 3 (Z): dZ/dt = -1.89Z - 4X - 4Y - 2X^2 ===
* sum = 1.89Z + 4X + 4Y + 2X^2
XU3 0 n3 vcc vee z {opamp.subckt_name}
C3 n3 z 10n
R3z z n3 52.9k
R3x x n3 25k
R3y y n3 25k
R3m w_x2 n3 5k
*
* === Multipliers (squares) ===
* W_y2 = Y*Y/10
XM1 y 0 y 0 0 w_y2 vcc vee {mult.subckt_name}
* W_z2 = Z*Z/10
XM2 z 0 z 0 0 w_z2 vcc vee {mult.subckt_name}
* W_x2 = X*X/10
XM3 x 0 x 0 0 w_x2 vcc vee {mult.subckt_name}
*
.ic V(x)=-2.5 V(y)=0.0 V(z)=0.0
*
.tran 10u 100m 10m uic
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
