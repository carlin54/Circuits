from circuits.base import BaseCircuit
from src.registry import ModelRegistry


class AizawaCircuit(BaseCircuit):
    NAME = "aizawa"
    DESCRIPTION = "Aizawa Attractor - Mushroom/Shell Shape"
    PLOT_AXES = ("v(x)", "v(y)")

    def generate_netlist(self, registry: ModelRegistry) -> str:
        opamp = registry.get_opamp("LT1057")
        mult = registry.get_multiplier("AD633")
        inc_opamp = opamp.get_include()
        inc_mult = mult.get_include()

        # Aizawa: dx/dt=(z-b)x-dy, dy/dt=dx+(z-b)y,
        #         dz/dt=c+az-z^3/3-(x^2+y^2)(1+ez)+fzx^3
        # a=0.95, b=0.7, c=0.6, d=3.5, e=0.25, f=0.1
        # Ranges: x~[-1.5,1.5], y~[-1.5,1.5], z~[-1,2]
        # No scaling needed - small signals.
        #
        # This is complex. Use behavioral sources for the hard nonlinear terms
        # (z^3, x^3, x^2+y^2) while keeping the structure op-amp based.
        # tau = 100k * 10nF = 1ms

        return f"""\
Aizawa Attractor - Analog Computer (Hybrid)
*
{inc_opamp}
{inc_mult}
*
VCC vcc 0 15
VEE vee 0 -15
*
* === Integrator 1 (X): dX/dt = (Z-0.7)*X - 3.5*Y ===
* Use behavioral source for (Z-0.7)*X product
* sum = -((Z-0.7)*X - 3.5Y) = -(Z-0.7)*X + 3.5Y
* Feed B_zx(=(Z-0.7)*X) inverted through appropriate R
* Feed Y through 100k/3.5=28.6k: contributes 3.5Y
B_zx zx_node 0 V = (V(z)-0.7)*V(x)
XU1 0 n1 vcc vee x {opamp.subckt_name}
C1 n1 x 10n
R1b mzx n1 100k
R1y y n1 28.6k
* Inverter for zx
XU8 0 n8 vcc vee mzx {opamp.subckt_name}
R8a zx_node n8 10k
R8b n8 mzx 10k
*
* === Integrator 2 (Y): dY/dt = 3.5*X + (Z-0.7)*Y ===
* sum = -(3.5X + (Z-0.7)*Y) = -3.5X - (Z-0.7)*Y
* Feed mx(=-X) through 100k/3.5=28.6k: contributes -3.5X ✓
* Feed B_zy(=(Z-0.7)*Y) inverted
B_zy zy_node 0 V = (V(z)-0.7)*V(y)
XU2 0 n2 vcc vee y {opamp.subckt_name}
C2 n2 y 10n
R2x mx n2 28.6k
R2b mzy n2 100k
* Inverter for zy
XU9 0 n9 vcc vee mzy {opamp.subckt_name}
R9a zy_node n9 10k
R9b n9 mzy 10k
*
* === Integrator 3 (Z): dZ/dt = 0.6 + 0.95Z - Z^3/3 - (X^2+Y^2)(1+0.25Z) + 0.1*Z*X^3 ===
* This is very complex. Use behavioral source for entire RHS.
B_dz dz_node 0 V = 0.6 + 0.95*V(z) - V(z)*V(z)*V(z)/3 - (V(x)*V(x)+V(y)*V(y))*(1+0.25*V(z)) + 0.1*V(z)*V(x)*V(x)*V(x)
* sum = -dZ/dt. Feed B_dz inverted through 100k.
XU3 0 n3 vcc vee z {opamp.subckt_name}
C3 n3 z 10n
R3b mdz n3 100k
* Inverter for dz
XU10 0 n10 vcc vee mdz {opamp.subckt_name}
R10a dz_node n10 10k
R10b n10 mdz 10k
*
* === Inverters ===
XU4 0 n4 vcc vee mx {opamp.subckt_name}
R4a x n4 10k
R4b n4 mx 10k
*
.ic V(x)=0.1 V(y)=0.0 V(z)=0.0
*
.tran 10u 250m 20m uic
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
