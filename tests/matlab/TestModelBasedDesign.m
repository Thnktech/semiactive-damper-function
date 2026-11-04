classdef TestModelBasedDesign < matlab.unittest.TestCase
    %TESTMODELBASEDDESIGN Design side of the model-based laws (v2): prediction model, LQR, MPC.
    %   Pure MATLAB, no Simulink: these tests check the design functions
    %   (QC_PREDICTION_MODEL, DESIGN_LQR, DESIGN_MPC, FORCE_TO_DAMPING) before
    %   the law slots Law_4_LQR and Law_5_MPC exist in controller.slx.
    %   Each test compares with something computed a different way: a hand
    %   formula, dlqr, or the MPC problem written out by hand.

    methods (TestClassSetup)
        function quietToolbox(tc)
            % mpcmove/mpcstate print the toolbox's default assumptions
            % (documented in D31); keep the test log readable.
            old = mpcverbosity('off');
            tc.addTeardown(@() mpcverbosity(old));
        end
    end

    methods (Test)
        % ---------- Prediction model (D30) ----------
        function model_natural_frequencies_match_hand_formula(tc)
            % Without damper force the model is the classic two-mass system.
            % Its undamped natural frequencies solve
            %   ms*mu*w^4 - (ks*mu + (ks+kt)*ms)*w^2 + ks*kt = 0,
            % derived by hand from the two equations of motion, independent
            % of how the A matrix was typed.
            P = setup_params();
            sys = qc_prediction_model(P);
            e = eig(sys.A(1:4, 1:4));                       % mechanical part only
            w_model = sort(imag(e(imag(e) > 0)));
            w2 = roots([P.ms*P.mu, -(P.ks*P.mu + (P.ks + P.kt)*P.ms), P.ks*P.kt]);
            w_hand = sort(sqrt(w2));
            tc.verifyEqual(w_model, w_hand, 'RelTol', 1e-9, ...
                sprintf('body %.2f Hz, wheel %.2f Hz', w_hand/(2*pi)));
        end

        function model_static_force_balance(tc)
            % A constant force F0 settles where the spring holds it: the
            % suspension deflects by -F0/ks, the tire load does not change
            % (the force is internal between body and wheel), the body is
            % at rest (acceleration 0).
            P = setup_params();
            sys = qc_prediction_model(P);
            F0 = 1000;
            x = -sys.A\(sys.B(:, 1)*F0);                     % steady state: 0 = A*x + B*F0
            y = sys.C*x;
            tc.verifyEqual(x', [-F0/P.ks, 0, 0, 0, F0], 'AbsTol', 1e-12);
            tc.verifyEqual(y', [0, 0, -F0/P.ks], 'AbsTol', 1e-9);
        end

        function model_road_velocity_lifts_whole_car(tc)
            % The road rising at constant speed w0 (a ramp) carries the
            % whole car up at w0, with no deflections: checks the sign and
            % place of the road input.
            P = setup_params();
            sys = qc_prediction_model(P);
            w0 = 0.3;
            x = -sys.A\(sys.B(:, 2)*w0);
            tc.verifyEqual(x', [0, w0, 0, w0, 0], 'AbsTol', 1e-12);
        end

        % ---------- LQR (D34) ----------
        function lqr_closed_loop_is_stable(tc)
            % With F_cmd = -K*x (no limits) every closed-loop pole lies
            % inside the unit circle at the controller rate.
            P = setup_params();
            sysd = c2d(qc_prediction_model(P), P.lqr.Ts, 'zoh');
            r = max(abs(eig(sysd.A - sysd.B(:, 1)*P.lqr.K)));
            tc.verifyLessThan(r, 1, sprintf('spectral radius %.6f', r));
        end

        function unconstrained_mpc_converges_to_lqr(tc)
            % Without limits, without the force-change weight and with a
            % long horizon, the MPC solves the same problem as the LQR, so
            % its first move must equal -K*x. This ties the MPC object
            % (toolbox) to the LQR (dlqr): same model, weights and scaling.
            % "Long" means several times the slowest closed-loop time
            % constant (0.76 s with the initial weights): the gap was
            % 1.4e-3 at 2 s, 3e-6 at 4 s and 4e-10 at 8 s, so 6 s is used.
            P = setup_params();
            P.mpc.p = 1200; P.mpc.m = 1200; P.mpc.du_weight = 0; P.mpc.F_bound = Inf;
            K = design_lqr(P, P.mpc.Ts);
            mpcobj = design_mpc(P);
            rng(3);
            for i = 1:5
                x = tc.randomState();
                xs = mpcstate(mpcobj); xs.Plant = x;
                u = mpcmove(mpcobj, xs, [], zeros(1, 3), 0);
                tc.verifyEqual(u, -K*x, 'RelTol', 1e-6, sprintf('state %d', i));
            end
        end

        % ---------- Classic MPC (D31) ----------
        function mpc_matches_hand_written_problem(tc)
            % The classic MPC problem written out by hand (stacked
            % predictions, blocked moves, quadratic cost; see condensedMove)
            % must give the same first move as the toolbox. Checks that
            % horizons, weights, scaling and the road disturbance mean what
            % D31 says. No limits, so the solution is a linear solve.
            P = setup_params();
            P.mpc.F_bound = Inf;
            mpcobj = design_mpc(P);
            rng(5);
            for i = 1:5
                x = tc.randomState(); w = 0.5*(2*rand - 1); u_prev = 2000*(2*rand - 1);
                xs = mpcstate(mpcobj); xs.Plant = x; xs.LastMove = u_prev;
                u = mpcmove(mpcobj, xs, [], zeros(1, 3), w);
                tc.verifyEqual(u, tc.condensedMove(P, x, w, u_prev), 'RelTol', 1e-6, 'AbsTol', 1e-6, ...
                    sprintf('state %d', i));
            end
        end

        function horizons_and_rate_come_from_P(tc)
            % Horizons and sample time are settings, not code: changing
            % P.mpc changes the controller (author's requirement).
            P = setup_params();
            P.mpc.p = 20; P.mpc.m = 3; P.mpc.Ts = 0.01;
            mpcobj = design_mpc(P);
            tc.verifyEqual([mpcobj.PredictionHorizon, mpcobj.ControlHorizon, mpcobj.Ts], [20, 3, 0.01]);
            xs = mpcstate(mpcobj);
            % Ideal states: the controller state is exactly the 5 plant states
            tc.verifyEqual([numel(xs.Plant), numel(xs.Disturbance), numel(xs.Noise)], [5, 0, 0]);
        end

        function preview_mpc_has_own_weights(tc)
            % D42: P.mpcp.y_weight tunes the preview MPC only; the classic MPC
            % keeps the shared weights P.mbc (the M8 reference stays unchanged).
            P = setup_params();
            P.mpcp.y_weight = [1; 0.3; 0.1];
            o5 = design_mpc(P); o6 = design_mpc(P, P.mpcp);
            tc.verifyEqual(o6.Weights.OV, [1 0.3 0.1]);
            tc.verifyEqual(o5.Weights.OV, P.mbc.y_weight(:)');
        end

        function unknown_formulation_is_rejected(tc)
            % A typo in P.mpc.formulation must stop, not fall back silently.
            P = setup_params();
            P.mpc.formulation = 99;
            tc.verifyError(@() design_mpc(P), 'design_mpc:formulation');
        end
    end

    methods (Test, TestTags = {'REQ-F-07'})
        function REQ_F_07_mpc_force_within_semiactive_limits(tc)
            % Random states; at every MPC step the limits come from the
            % current relative velocity, [c_min, c_max]*v_rel (D32). The QP
            % must return a feasible force inside them.
            P = setup_params();
            mpcobj = design_mpc(P);
            xs = mpcstate(mpcobj);
            opt = mpcmoveopt;
            rng(7);
            n = 300; worst = 0; nInfeasible = 0;
            for i = 1:n
                x = tc.randomState(); v = x(2) - x(4);
                lo = min(P.c_min*v, P.c_max*v); hi = max(P.c_min*v, P.c_max*v);
                opt.MVMin = lo; opt.MVMax = hi;
                xs.Plant = x;
                [u, info] = mpcmove(mpcobj, xs, [], zeros(1, 3), 0.5*(2*rand - 1), opt);
                nInfeasible = nInfeasible + ~strcmp(info.QPCode, 'feasible');
                worst = max([worst, lo - u, u - hi]);
            end
            tc.verifyEqual(nInfeasible, 0, 'every QP must be solved');
            tc.verifyLessThanOrEqual(worst, 1e-6, sprintf('largest limit violation %.3g N', worst));
            record_evidence('REQ-F-07', 'TestModelBasedDesign/REQ_F_07_mpc_force_within_semiactive_limits', ...
                'largest limit violation', worst, 'N');
        end
    end

    methods (Test, TestTags = {'REQ-F-06'})
        function REQ_F_06_dissipative_request_gives_F_over_v(tc)
            % Force opposes motion: damping is simply F/v_rel.
            P = setup_params();
            tc.verifyEqual(force_to_damping(500, 0.2, P), 2500, 'AbsTol', 1e-12);
            tc.verifyEqual(force_to_damping(-500, -0.2, P, 3), 2500, 'AbsTol', 1e-12);
        end

        function REQ_F_06_non_dissipative_request_goes_passive(tc)
            % Force would push with the motion (needs energy) -> passive.
            P = setup_params();
            tc.verifyEqual(force_to_damping(-500, 0.2, P), P.c_passive);
            tc.verifyEqual(force_to_damping(0, 0.2, P), P.c_passive);
        end

        function REQ_F_06_tiny_velocity_goes_passive(tc)
            % |v_rel| below eps: dividing would blow up -> passive (finite).
            P = setup_params();
            tc.verifyEqual(force_to_damping(500, 0.5*P.eps_vrel, P), P.c_passive);
            tc.verifyEqual(force_to_damping(500, 0, P), P.c_passive);
        end

        function REQ_F_06_solver_failure_goes_passive(tc)
            % MPC status <= 0 (no valid solution) -> passive, whatever F is.
            P = setup_params();
            tc.verifyEqual(force_to_damping(500, 0.2, P, 0), P.c_passive);
            tc.verifyEqual(force_to_damping(500, 0.2, P, -1), P.c_passive);
        end
    end

    methods (Static)
        function x = randomState()
            % Typical magnitudes on a rough road (SC-C80 order of size)
            x = [0.05; 0.5; 0.005; 1; 2000].*(2*rand(5, 1) - 1);
        end

        function u0 = condensedMove(P, x, w, u_prev)
            % Classic MPC written out by hand (no limits):
            %   min  sum_{i=1..p} |Wy*y(k+i)|^2 + sum_{i=0..p-1} wu*u(k+i)^2
            %        + sum_{i=0..m-1} wdu*(u(k+i) - u(k+i-1))^2
            %   moves after the control horizon are held: u(k+i) = u(k+m-1), i >= m
            %   road velocity w held constant over the horizon
            % Weights act on scaled variables: (weight/scale)^2.
            sysd = c2d(qc_prediction_model(P), P.mpc.Ts, 'zoh');
            A = sysd.A; Bu = sysd.B(:, 1); Bw = sysd.B(:, 2); C = sysd.C;
            p = P.mpc.p; m = P.mpc.m; ny = 3;
            Sx = zeros(ny*p, 5); Su = zeros(ny*p, p); Sw = zeros(ny*p, 1);
            for i = 1:p
                rows = (i - 1)*ny + (1:ny);
                Sx(rows, :) = C*A^i;
                for l = 0:i - 1
                    Su(rows, l + 1) = C*A^(i - 1 - l)*Bu;
                    Sw(rows) = Sw(rows) + C*A^(i - 1 - l)*Bw*w;
                end
            end
            T = zeros(p, m);                            % blocking: u(k+i) = z(min(i+1, m))
            for i = 1:p
                T(i, min(i, m)) = 1;
            end
            Wy = kron(eye(p), diag((P.mbc.y_weight(:)./P.mbc.y_scale(:)).^2));
            wu = (P.mbc.u_weight/P.mbc.u_scale)^2;
            wdu = (P.mpc.du_weight/P.mbc.u_scale)^2;
            Dm = eye(m) - diag(ones(m - 1, 1), -1);     % move differences
            e1 = [1; zeros(m - 1, 1)];                  % first difference uses u_prev
            H = T'*(Su'*Wy*Su)*T + wu*(T'*T) + wdu*(Dm'*Dm);
            f = T'*Su'*Wy*(Sx*x + Sw) - wdu*Dm'*e1*u_prev;
            z = -H\f;
            u0 = z(1);
        end
    end
end
