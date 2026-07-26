from circuits.base import BaseCircuit
from src.registry import ModelRegistry


class ChuaCircuit(BaseCircuit):
    NAME = "chua"
    DESCRIPTION = "Chua's Circuit - Double Scroll Attractor"
    PLOT_AXES = ("v(x)", "v(y)")

    def generate_netlist(self, registry: ModelRegistry) -> str:
        opamp = registry.get_opamp("LT1057")
        inc_opamp = opamp.get_include()

        # Chua: dx/dt=alpha*(y-x-f(x)), dy/dt=x-y+z, dz/dt=-beta*y
        # alpha=15.6, beta=28.58, m0=-1.143, m1=-0.714
        # f(x) = m1*x + 0.5*(m0-m1)*(|x+1|-|x-1|)
        # Ranges: x~[-2.5,2.5], y~[-0.4,0.4], z~[-4,4]
        # No voltage scaling needed.
        # tau = 100k * 10nF = 1ms
        # Use behavioral source for f(x) nonlinearity

        return f"""\
Chua Double Scroll - Analog Computer
*
{inc_opamp}
*
VCC vcc 0 15
VEE vee 0 -15
*
* === Integrator 1 (X): dX/dt = alpha*(Y - X - f(X)) ===
* alpha=15.6. f(X) = m1*X + 0.5*(m0-m1)*(|X+1|-|X-1|)
* sum = -(alpha*(Y-X-f(X))) = alpha*(-Y+X+f(X))
*      = alpha*(X + f(X) - Y)
* Decompose f(X) into behavioral source output.
* Feed mx(=-X) through 100k/alpha=6.41k: contributes (-X)*15.6... wait.
* Let me be careful with signs.
* sum(Vi*Gi) must equal -[desired dX/dt] because integrator inverts.
* desired: dX/dt = 15.6*(Y-X-f(X))
* so sum = -15.6*(Y-X-f(X)) = 15.6*(-Y+X+f(X)) = 15.6*X - 15.6*Y + 15.6*f(X)
*
* Feed X through 100k/15.6=6.41k: contributes X*15.6 ✓
* Feed my(=-Y) through 6.41k: contributes (-Y)*15.6 = -15.6Y...
*   Wait we need -15.6Y in sum. (-Y)*15.6 = -15.6Y ✓
* Feed fx_out through 6.41k: contributes fx*15.6 ✓ (where fx = f(X))
*
B_fx fx_out 0 V = -0.714*V(x) + 0.5*(-1.143+0.714)*(abs(V(x)+1)-abs(V(x)-1))
XU1 0 n1 vcc vee x {opamp.subckt_name}
C1 n1 x 10n
R1x x n1 6.41k
R1y my n1 6.41k
R1f fx_out n1 6.41k
*
* === Integrator 2 (Y): dY/dt = X - Y + Z ===
* sum = -(X-Y+Z) = -X+Y-Z
* Feed mx through 100k: contributes (-X)*1=-X ✓
* Feed Y through 100k: contributes Y ✓
* Feed mz through 100k: contributes (-Z)*1=-Z ✓
XU2 0 n2 vcc vee y {opamp.subckt_name}
C2 n2 y 10n
R2x mx n2 100k
R2y y n2 100k
R2z mz n2 100k
*
* === Integrator 3 (Z): dZ/dt = -beta*Y = -28.58*Y ===
* sum = -(-28.58Y) = 28.58Y
* Feed Y through 100k/28.58=3.5k: contributes Y*28.58 ✓
XU3 0 n3 vcc vee z {opamp.subckt_name}
C3 n3 z 10n
R3y y n3 3.5k
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
*
.ic V(x)=0.5 V(y)=0.0 V(z)=0.0
*
.tran 10u 120m 10m uic
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
