function mpcobj = design_mpc(P)
%DESIGN_MPC MPC controller object for the law slot Law_5_MPC (D31).
%   mpcobj = DESIGN_MPC(P) builds the MPC selected by P.mpc.formulation.
%   The MPC Controller block in Law_5_MPC reads it from the variable
%   mpc_law5 (set by SETUP_PARAMS and SIMULATE_HARNESS).
%
%   Formulations (P.mpc.formulation, a number so that P stays a numeric
%   struct for code generation):
%     1  classic   linear MPC, quadratic cost, receding horizon; the
%                  semi-active force limits are given to the QP every step
%                  through the block's umin/umax inports (D31, D32)
%   A new formulation is one more case below plus its own local function.
%   If it needs a different block (adaptive, explicit, nonlinear MPC), it
%   gets its own law slot and reuses QC_PREDICTION_MODEL and the
%   force-to-damping logic (D31).

% The toolbox prints its default assumptions on every construction; they
% are documented in D31, so keep the command window quiet.
old = mpcverbosity('off');
restore = onCleanup(@() mpcverbosity(old));

switch P.mpc.formulation
    case 1
        mpcobj = classic(P);
    otherwise
        error('design_mpc:formulation', 'Unknown MPC formulation %g (see design_mpc, D31).', P.mpc.formulation);
end
end

function mpcobj = classic(P)
% Prediction model: force request = manipulated variable (MV), road
% velocity = measured disturbance (MD), all three outputs measured.
plant = setmpcsignals(qc_prediction_model(P), 'MV', 1, 'MD', 2);
mpcobj = mpc(plant, P.mpc.Ts, P.mpc.p, P.mpc.m);

% Scaling makes the weights comparable: each output and the force are
% divided by a typical magnitude before weighting (same as DESIGN_LQR).
mpcobj.MV.ScaleFactor = P.mbc.u_scale;
for j = 1:3
    mpcobj.OV(j).ScaleFactor = P.mbc.y_scale(j);
end
mpcobj.Weights.OV = P.mbc.y_weight(:)';
mpcobj.Weights.MV = P.mbc.u_weight;
mpcobj.Weights.MVRate = P.mpc.du_weight;

% Finite placeholder limits: the block's umin/umax inports replace them
% every step with the semi-active limits [c_min, c_max]*v_rel (D32). The
% toolbox needs finite limits in the object to accept those inports.
mpcobj.MV.Min = -P.mpc.F_bound;
mpcobj.MV.Max =  P.mpc.F_bound;

% Ideal states (D30): the block receives x directly ("custom" estimation),
% so no Kalman filter and no extra disturbance states are added. The
% controller state is then exactly the 5 plant states.
setoutdist(mpcobj, 'model', ss(zeros(3, 1)));
setEstimator(mpcobj, 'custom');
end
