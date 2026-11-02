function c = force_to_damping(F, v_rel, P, qp_status)
%FORCE_TO_DAMPING Requested damping from a requested damper force (D32, REQ-F-06).
%   c = FORCE_TO_DAMPING(F, v_rel, P)             LQR (no solver status)
%   c = FORCE_TO_DAMPING(F, v_rel, P, qp_status)  MPC
%
%   Reference for the Force_to_damping blocks in Law_4_LQR and Law_5_MPC:
%   the Simulink tests compare the blocks with this function.
%
%   A semi-active damper can only remove energy: its force must oppose the
%   relative velocity, F*v_rel > 0. Then c = F/v_rel. Otherwise the request
%   cannot be produced and the law falls back to passive damping:
%     - F*v_rel <= 0          request would need energy (author's decision)
%     - |v_rel| < eps_vrel    division by ~0 (same guard as skyhook, D25)
%     - qp_status <= 0        MPC solver gave no valid solution
%   Clipping to [c_min, c_max] stays in Damping_to_current (D24).

if nargin < 4
    qp_status = 1;                 % LQR: no solver, always valid
end
if qp_status <= 0 || abs(v_rel) < P.eps_vrel || F*v_rel <= 0
    c = P.c_passive;
else
    c = F/v_rel;
end
end
