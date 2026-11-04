function in = set_mpc_objects(in, P)
%SET_MPC_OBJECTS Give a simulation the MPC objects of the law slots (D31, D40).
%   in = SET_MPC_OBJECTS(in, P) sets on the Simulink.SimulationInput in:
%     mpc_law5  Law_5_MPC, classic MPC from P.mpc
%     mpc_law6  Law_6_MPC_Preview, preview MPC from P.mpcp
%
%   Every law slot compiles in every run, also when its mode is never
%   selected, so every simulation of the controller or the harness needs
%   both objects. Building them from this run's P keeps model and P in step.

in = in.setVariable('mpc_law5', design_mpc(P));
in = in.setVariable('mpc_law6', design_mpc(P, P.mpcp));
end
