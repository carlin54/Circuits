from circuits.base import BaseCircuit
from src.registry import ModelRegistry


class SprottCircuit(BaseCircuit):
    NAME = "sprott_a"
    DESCRIPTION = "Sprott Case A - Minimal Chaotic Flow"
    PLOT_AXES = ("v(x)", "v(y)")

    def generate_netlist(self, registry: ModelRegistry) -> str:
        opamp = registry.get_opamp("LT1057")
        mult = registry.get_multiplier("AD633")
        inc_opamp = opamp.get_include()
        inc_mult = mult.get_include()

        # Sprott A: dx/dt=y, dy/dt=-x+yz, dz/dt=1-y^2
        # Ranges: x~[-2,2], y~[-2,2], z~[-1,2]
        # No scaling needed - fits in +/-15V easily
        # tau = 100k * 10nF = 1ms
        # One multiplier for yz, one for y^2

        return f"""\
Sprott Case A - Minimal Chaotic Flow
*
{inc_opamp}
{inc_mult}
*
VCC vcc 0 15
VEE vee 0 -15
*
* === Integrator 1 (X): dX/dt = Y ===
* sum = -Y. Feed my(=-Y) through 100k (gain 1)
* Wait: sum(Vi*Gi) = -Y. Feed Y with gain -1? No.
* dX/dt = Y => -(1/tau)*sum = Y => sum = -Y*tau... no.
* dVout/dt = -(1/tau)*sum(Vi*Gi)
* Want dX/dt = Y. So -(1/tau)*sum = Y => sum = -Y
* Feed my(=-Y) through 100k: contributes (-Y)*1 = -Y ✓
XU1 0 n1 vcc vee x {opamp.subckt_name}
C1 n1 x 10n
R1y my n1 100k
*
* === Integrator 2 (Y): dY/dt = -X + YZ ===
* sum = -(-X + YZ) = X - YZ
* Feed X through 100k: contributes X ✓
* Feed mw_yz(=-YZ/10) through 10k (gain 10): contributes (-YZ/10)*10 = -YZ ✓
XU2 0 n2 vcc vee y {opamp.subckt_name}
C2 n2 y 10n
R2x x n2 100k
R2m mw_yz n2 10k
*
* === Integrator 3 (Z): dZ/dt = 1 - Y^2 ===
* sum = -(1 - Y^2) = -1 + Y^2
* Feed Vref=-1V through 100k: contributes -1 ✓
* Feed w_y2(=Y*Y/10) through 10k (gain 10): contributes (Y^2/10)*10 = Y^2 ✓
XU3 0 n3 vcc vee z {opamp.subckt_name}
C3 n3 z 10n
Vdc ndc 0 -1.0
R3dc ndc n3 100k
R3m w_y2 n3 10k
*
* === Multipliers ===
* W_yz = Y*Z/10
XM1 y 0 z 0 0 w_yz vcc vee {mult.subckt_name}
* W_y2 = Y*Y/10
XM2 y 0 y 0 0 w_y2 vcc vee {mult.subckt_name}
* mw_yz = -YZ/10
XU7 0 n7 vcc vee mw_yz {opamp.subckt_name}
R7a w_yz n7 10k
R7b n7 mw_yz 10k
*
* === Inverters ===
XU4 0 n4 vcc vee mx {opamp.subckt_name}
R4a x n4 10k
R4b n4 mx 10k
XU5 0 n5 vcc vee my {opamp.subckt_name}
R5a y n5 10k
R5b n5 my 10k
*
.ic V(x)=0.1 V(y)=0.1 V(z)=0.1
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
