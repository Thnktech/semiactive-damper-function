function mpcobj = design_mpc(P, M)
%DESIGN_MPC MPC controller object for an MPC law slot (D31, D40).
%   mpcobj = DESIGN_MPC(P) builds the MPC of Law_5_MPC from the settings
%   P.mpc; the block reads it from the variable mpc_law5.
%   mpcobj = DESIGN_MPC(P, M) builds it from the settings M instead, e.g.
%   DESIGN_MPC(P, P.mpcp) for Law_6_MPC_Preview (variable mpc_law6).
%   SETUP_PARAMS and SET_MPC_OBJECTS set both variables.
%
%   Formulations (M.formulation, a number so that P stays a numeric
%   struct for code generation):
%     1  classic   linear MPC, quadratic cost, receding horizon; the
%                  semi-active force limits are given to the QP every step
%                  through the block's umin/umax inports (D31, D32)
%     2  preview   the same object; the slot gives the block the road
%                  velocity over the horizon as a (p+1)x1 measured
%                  disturbance instead of one value (D40). The block
%                  takes the preview from the signal size, so the
%                  object itself needs no change
%   A new formulation is one more case below plus its own local function.
%   If it needs a different block (adaptive, explicit, nonlinear MPC), it
%   gets its own law slot and reuses QC_PREDICTION_MODEL and the
%   force-to-damping logic (D31).

% The toolbox prints its default assumptions on every construction; they
% are documented in D31, so keep the command window quiet.
old = mpcverbosity('off');
restore = onCleanup(@() mpcverbosity(old));

if nargin < 2
    M = P.mpc;
end
switch M.formulation
    case {1, 2}
        mpcobj = classic(P, M);
    otherwise
        error('design_mpc:formulation', 'Unknown MPC formulation %g (see design_mpc, D31).', M.formulation);
end
end

function mpcobj = classic(P, M)
% Prediction model: force request = manipulated variable (MV), road
% velocity = measured disturbance (MD), all three outputs measured.
plant = setmpcsignals(qc_prediction_model(P), 'MV', 1, 'MD', 2);
mpcobj = mpc(plant, M.Ts, M.p, M.m);

% Scaling makes the weights comparable: each output and the force are
% divided by a typical magnitude before weighting (same as DESIGN_LQR).
mpcobj.MV.ScaleFactor = P.mbc.u_scale;
for j = 1:3
    mpcobj.OV(j).ScaleFactor = P.mbc.y_scale(j);
end
mpcobj.Weights.OV = P.mbc.y_weight(:)';
mpcobj.Weights.MV = P.mbc.u_weight;
mpcobj.Weights.MVRate = M.du_weight;

% Finite placeholder limits: the block's umin/umax inports replace them
% every step with the semi-active limits [c_min, c_max]*v_rel (D32). The
% toolbox needs finite limits in the object to accept those inports.
mpcobj.MV.Min = -M.F_bound;
mpcobj.MV.Max =  M.F_bound;

% Ideal states (D30): the block receives x directly ("custom" estimation),
% so no Kalman filter and no extra disturbance states are added. The
% controller state is then exactly the 5 plant states.
setoutdist(mpcobj, 'model', ss(zeros(3, 1)));
setEstimator(mpcobj, 'custom');
end
