from circuits.base import BaseCircuit
from src.registry import ModelRegistry


class RosslerCircuit(BaseCircuit):
    NAME = "rossler"
    DESCRIPTION = "Rossler Attractor - Spiral Chaos"
    PLOT_AXES = ("v(x)", "v(y)")

    def generate_netlist(self, registry: ModelRegistry) -> str:
        opamp = registry.get_opamp("LT1057")
        mult = registry.get_multiplier("AD633")
        inc_opamp = opamp.get_include()
        inc_mult = mult.get_include()

        # Rossler: dx/dt=-(y+z), dy/dt=x+0.2y, dz/dt=0.2+xz-5.7z
        # Scaling: X=x, Y=y, Z=z/5 (keeps Z in +/-5V range)
        # Circuit domain: dX/dt=-(Y+5Z), dY/dt=X+0.2Y, dZ/dt=0.04+XZ-5.7Z
        # tau = RC = 100k * 10nF = 1ms

        return f"""\
Rossler Attractor - Analog Computer
*
{inc_opamp}
{inc_mult}
*
VCC vcc 0 15
VEE vee 0 -15
*
* === Integrator 1 (X): dX/dt = -(Y + 5Z) ===
* Inverting integrator: dX/dt = -(1/tau)*sum(Vi*Gi)
* Need dX/dt = -(Y+5Z), so sum(Vi*Gi) = Y+5Z
* Feed Y through 100k (gain 1), Z through 20k (gain 5)
XU1 0 n1 vcc vee x {opamp.subckt_name}
C1 n1 x 10n
R1y y n1 100k
R1z z n1 20k
*
* === Integrator 2 (Y): dY/dt = X + 0.2Y ===
* Need sum = -(X+0.2Y) = -X - 0.2Y
* Feed mx through 100k (gain 1 on -X = -X)
* Feed my through 500k (gain 0.2 on -Y = -0.2Y)
XU2 0 n2 vcc vee y {opamp.subckt_name}
C2 n2 y 10n
R2x mx n2 100k
R2y my n2 500k
*
* === Integrator 3 (Z): dZ/dt = 0.04 + X*Z - 5.7*Z ===
* Need sum = -(0.04 + XZ - 5.7Z) = -0.04 - XZ + 5.7Z
* Multiplier gives W=X*Z/10. Need -XZ => feed mw with gain 10 (R=10k)
* Feed Z through 17.5k (gain 5.7, positive Z contributes +5.7Z to sum)
* Feed -0.04V DC through 100k (gain 1, contributes -0.04)
XU3 0 n3 vcc vee z {opamp.subckt_name}
C3 n3 z 10n
Vref nref 0 -0.04
R3dc nref n3 100k
R3m mw n3 10k
R3z z n3 17.5k
*
* === Multiplier: W = X*Z/10 ===
XM1 x 0 z 0 0 w vcc vee {mult.subckt_name}
*
* === Inverters ===
* mw = -(XZ/10)
XU7 0 n7 vcc vee mw {opamp.subckt_name}
R7a w n7 10k
R7b n7 mw 10k
* mx = -X
XU4 0 n4 vcc vee mx {opamp.subckt_name}
R4a x n4 10k
R4b n4 mx 10k
* my = -Y
XU5 0 n5 vcc vee my {opamp.subckt_name}
R5a y n5 10k
R5b n5 my 10k
*
.ic V(x)=1.0 V(y)=1.0 V(z)=0.0
*
.tran 10u 400m 50m uic
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
