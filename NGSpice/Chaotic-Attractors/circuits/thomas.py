from circuits.base import BaseCircuit
from src.registry import ModelRegistry


class ThomasCircuit(BaseCircuit):
    NAME = "thomas"
    DESCRIPTION = "Thomas Attractor - Cyclic Ribbon Loops"
    PLOT_AXES = ("v(x)", "v(y)")

    def generate_netlist(self, registry: ModelRegistry) -> str:
        opamp = registry.get_opamp("LT1057")
        inc_opamp = opamp.get_include()

        # Thomas: dx/dt=sin(y)-bx, dy/dt=sin(z)-by, dz/dt=sin(x)-bz
        # b=0.208186. Ranges: ~[-4,4] for all. No scaling needed.
        # Uses behavioral B sources for sin() function.
        # tau = 100k * 10nF = 1ms

        return f"""\
Thomas Attractor - Analog Computer with Behavioral sin()
*
{inc_opamp}
*
VCC vcc 0 15
VEE vee 0 -15
*
* === Integrator 1 (X): dX/dt = sin(Y) - 0.208186*X ===
* sum = -(sin(Y) - 0.208186X) = -sin(Y) + 0.208186X
* Feed msiny(=-sin(Y)) through 100k (gain 1): contributes -sin(Y) ✓
* Feed X through 100k/0.208186=480k: contributes 0.208186X ✓
XU1 0 n1 vcc vee x {opamp.subckt_name}
C1 n1 x 10n
R1s msiny n1 100k
R1x x n1 480k
*
* === Integrator 2 (Y): dY/dt = sin(Z) - 0.208186*Y ===
* sum = -sin(Z) + 0.208186Y
XU2 0 n2 vcc vee y {opamp.subckt_name}
C2 n2 y 10n
R2s msinz n2 100k
R2y y n2 480k
*
* === Integrator 3 (Z): dZ/dt = sin(X) - 0.208186*Z ===
* sum = -sin(X) + 0.208186Z
XU3 0 n3 vcc vee z {opamp.subckt_name}
C3 n3 z 10n
R3s msinx n3 100k
R3z z n3 480k
*
* === Behavioral sin() sources ===
* Using B sources to compute sin of each variable
B_siny siny 0 V = sin(V(y))
B_sinz sinz 0 V = sin(V(z))
B_sinx sinx 0 V = sin(V(x))
*
* === Inverters for sin outputs ===
* msiny = -sin(Y)
XU4 0 n4 vcc vee msiny {opamp.subckt_name}
R4a siny n4 10k
R4b n4 msiny 10k
* msinz = -sin(Z)
XU5 0 n5 vcc vee msinz {opamp.subckt_name}
R5a sinz n5 10k
R5b n5 msinz 10k
* msinx = -sin(X)
XU6 0 n6 vcc vee msinx {opamp.subckt_name}
R6a sinx n6 10k
R6b n6 msinx 10k
*
.ic V(x)=1.0 V(y)=1.0 V(z)=1.0
*
* Thomas is slow (b is small), need long sim time
.tran 50u 600m 50m uic
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
