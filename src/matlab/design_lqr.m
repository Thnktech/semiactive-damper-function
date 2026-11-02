function K = design_lqr(P, Ts)
%DESIGN_LQR State-feedback gain of the LQR law slot Law_4_LQR (D34).
%   K = DESIGN_LQR(P, Ts) returns the row vector K (1x5) for F_cmd = -K*x,
%   x as in QC_PREDICTION_MODEL, for sample time Ts [s].
%
%   The cost uses the same output weights and scales as the MPC (P.mbc), so
%   both laws pursue the same goal:
%     J = sum over k of  y'*W*y + R*F_cmd^2,
%     W = diag((y_weight./y_scale).^2),  R = (u_weight/u_scale)^2
%   The road velocity is a disturbance: the LQR does not use it.
%
%   Why an LQR before the MPC: an unconstrained MPC with a long horizon
%   converges to this gain. TestModelBasedDesign checks that, which verifies
%   the prediction model, the weights and the scaling independently of the
%   MPC toolbox's own code.

sys = qc_prediction_model(P);
sysd = c2d(sys(:, 'F_cmd'), Ts, 'zoh');     % force input only
W = diag((P.mbc.y_weight(:)./P.mbc.y_scale(:)).^2);
Q = sysd.C'*W*sysd.C;                       % y = C*x (no direct feedthrough)
R = (P.mbc.u_weight/P.mbc.u_scale)^2;
K = dlqr(sysd.A, sysd.B, Q, R);
end
