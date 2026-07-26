from circuits.base import BaseCircuit
from src.registry import ModelRegistry


class LorenzCircuit(BaseCircuit):
    NAME = "lorenz"
    DESCRIPTION = "Lorenz Butterfly Attractor"
    PLOT_AXES = ("v(x)", "v(z)")

    def generate_netlist(self, registry: ModelRegistry) -> str:
        opamp = registry.get_opamp("LT1057")
        mult = registry.get_multiplier("AD633")
        inc_opamp = opamp.get_include()
        inc_mult = mult.get_include()

        # Lorenz: dx/dt=sigma*(y-x), dy/dt=x*(rho-z)-y, dz/dt=x*y-beta*z
        # sigma=10, rho=28, beta=8/3
        # Scaling: X=x/4, Y=y/4, Z=z/8 (keeps all in +/-10V)
        # Then x=4X, y=4Y, z=8Z
        # dX/dt = (1/4)*dx/dt = (1/4)*10*(4Y-4X) = 10*(Y-X)
        # dY/dt = (1/4)*dy/dt = (1/4)*(4X*(28-8Z)-4Y) = X*(28-8Z) - Y
        #       = 28X - 8XZ - Y
        #       Multiplier: W1 = X*Z/10, need 8XZ = 80*W1... too high gain.
        #       Better scaling: X=x/2, Y=y/2, Z=z/4
        #       dX/dt = 10*(Y-X)
        #       dY/dt = (1/2)*(2X*(28-4Z)-2Y) = X*(28-4Z)-Y = 28X - 4XZ - Y
        #       dZ/dt = (1/4)*(2X*2Y - (8/3)*4Z) = XY - (8/3)Z
        #       Mult for XZ: W1=X*Z/10, need 4XZ = 40*W1. Still high.
        #
        # Simplest: no scaling, rely on op-amp rails to soft-clip.
        # Lorenz x~[-20,20], y~[-30,30], z~[0,50]. z will clip at 15V.
        # Scale everything by 1/4: X=x/4, Y=y/4, Z=z/4
        # x=4X, y=4Y, z=4Z
        # dX/dt = (sigma/4)*(4Y-4X) = sigma*(Y-X) = 10*(Y-X)
        # dY/dt = (1/4)*(4X*(rho-4Z) - 4Y) = X*(28-4Z) - Y
        #       = 28X - 4XZ - Y
        # dZ/dt = (1/4)*(4X*4Y - beta*4Z) = 4XY - (beta)Z = 4XY - (8/3)Z
        #
        # Multiplier outputs: W_xz = X*Z/10, W_xy = X*Y/10
        # 4XZ = 40*W_xz (gain 40 on mult output -> R=100k/40=2.5k)
        # 4XY = 40*W_xy (gain 40 -> R=2.5k)
        # These gains are high but within op-amp capability.
        #
        # tau = 100k * 10nF = 1ms

        return f"""\
Lorenz Butterfly - Analog Computer
*
{inc_opamp}
{inc_mult}
*
VCC vcc 0 15
VEE vee 0 -15
*
* Scaling: X=x/4, Y=y/4, Z=z/4. tau=1ms.
*
* === Integrator 1 (X): dX/dt = 10*(Y-X) = 10Y - 10X ===
* sum = -(10Y - 10X) = -10Y + 10X = 10X - 10Y
* Feed X through 10k (gain 10), mY through 10k (gain 10)
* Wait: sum must give -(desired). desired=10Y-10X.
* sum = -(10Y-10X) = 10X-10Y
* Feed X through 100k/10=10k, and feed my(=-Y) through 10k
XU1 0 n1 vcc vee x {opamp.subckt_name}
C1 n1 x 10n
R1x x n1 10k
R1y my n1 10k
*
* === Integrator 2 (Y): dY/dt = 28X - 4XZ - Y ===
* sum = -(28X - 4XZ - Y) = -28X + 4XZ + Y
* Feed mx through 100k/28=3.57k (contributes -28X... wait)
* Feeding mx(=-X) through R gives current = -X/R -> contributes (-X)*(100k/R)/tau
* Let me be careful:
* dY/dt = -(1/tau)*sum where sum = sum of (Vi/Ri)*tau = sum of Vi*(100k/Ri)
* No, more precisely: dVout/dt = -(1/C)*sum(Vi/Ri)
* With C=10nF: dVout/dt = -(1/10n)*sum(Vi/Ri)
* And tau=RC=100k*10n=1ms, so dVout/dt = -(1/tau)*sum(Vi*100k/Ri)
* = -(1/tau)*sum(Vi*Gi) where Gi=100k/Ri
*
* Want dY/dt = 28X - 4XZ - Y
* -(1/tau)*sum(Vi*Gi) = 28X - 4XZ - Y
* sum(Vi*Gi) = -(28X - 4XZ - Y) = -28X + 4XZ + Y
* Feed mx(=-X) with gain 28: R=100k/28=3.57k -> contributes (-X)*28 = -28X ✓
* Feed w_xz(=XZ/10) with gain 40: R=100k/40=2.5k -> contributes (XZ/10)*40 = 4XZ ✓
* Feed Y with gain 1: R=100k -> contributes Y ✓
XU2 0 n2 vcc vee y {opamp.subckt_name}
C2 n2 y 10n
R2x mx n2 3.57k
R2m w_xz n2 2.5k
R2y y n2 100k
*
* === Integrator 3 (Z): dZ/dt = 4XY - (8/3)Z ===
* sum(Vi*Gi) = -(4XY - (8/3)Z) = -4XY + (8/3)Z
* Feed mw_xy(=-XY/10) with gain 40: R=2.5k -> contributes (-XY/10)*40 = -4XY ✓
* Feed Z with gain 8/3=2.667: R=100k/2.667=37.5k -> contributes Z*2.667 ✓
XU3 0 n3 vcc vee z {opamp.subckt_name}
C3 n3 z 10n
R3m mw_xy n3 2.5k
R3z z n3 37.5k
*
* === Multipliers ===
* W_xz = X*Z/10
XM1 x 0 z 0 0 w_xz vcc vee {mult.subckt_name}
* W_xy = X*Y/10
XM2 x 0 y 0 0 w_xy vcc vee {mult.subckt_name}
* Inverted: mw_xy = -XY/10
XU7 0 n7 vcc vee mw_xy {opamp.subckt_name}
R7a w_xy n7 10k
R7b n7 mw_xy 10k
*
* === Inverters ===
* mx = -X
XU4 0 n4 vcc vee mx {opamp.subckt_name}
R4a x n4 10k
R4b n4 mx 10k
* my = -Y
XU5 0 n5 vcc vee my {opamp.subckt_name}
R5a y n5 10k
R5b n5 my 10k
*
.ic V(x)=0.25 V(y)=0.25 V(z)=0.25
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
        return ("v(x)", "v(z)")
