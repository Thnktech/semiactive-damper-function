classdef TestModelBasedLaws < matlab.unittest.TestCase
    %TESTMODELBASEDLAWS Law slots of the model-based laws in controller.slx (v2).
    %   The controller is driven alone with all 8 inputs. Each input row is
    %   held long enough for the rate limiter to settle; the settled current
    %   is compared with a hand calculation that does not use the model:
    %     F = -K*x  ->  force_to_damping  ->  clip [c_min, c_max]  ->  damper map.

    properties (Constant)
        Model = 'controller'
        Hold = 15        % samples per input row: 10 for the full current range + output delay
    end

    methods (TestClassSetup)
        function loadModel(tc)
            load_system(tc.Model);
            tc.addTeardown(@() close_system(tc.Model, 0));
        end
        function quietToolbox(tc)
            % mpcmove/mpcstate print the toolbox's default assumptions
            % (documented in D31); keep the test log readable.
            old = mpcverbosity('off');
            tc.addTeardown(@() mpcverbosity(old));
        end
    end

    methods (Test, TestTags = {'REQ-F-06'})
        function REQ_F_06_lqr_slot_matches_hand_calculation(tc)
            % 60 random vehicle states. The set must contain all three cases
            % of the rule (dissipative, non-dissipative, |v_rel| < eps), else
            % the comparison would not prove the whole rule.
            P = setup_params();
            rng(21);
            n = 60;
            X = [0.05 0.5 0.005 1 2000].*(2*rand(n, 5) - 1);      % [zs-zu, zs_dot, zu-zr, zu_dot, F_d]
            X(1:5, 4) = X(1:5, 2) + 0.4*P.eps_vrel*(2*rand(5, 1) - 1);   % 5 rows with |v_rel| < eps
            [I_model, I_hand, cases] = tc.compare(P, X);
            tc.assertTrue(all(ismember({'dissipative', 'non-dissipative', 'tiny v_rel'}, cases)), ...
                'test states must cover every case of the rule');
            err = max(abs(I_model - I_hand));
            tc.verifyLessThanOrEqual(err, 1e-12, sprintf('largest current difference %.3g A', err));
            record_evidence('REQ-F-06', 'TestModelBasedLaws/REQ_F_06_lqr_slot_matches_hand_calculation', ...
                'largest current difference, LQR slot vs rule', err, 'A');
        end
        function REQ_F_06_mpc_slot_matches_mpcmove(tc)
            % Random states held for 40 MPC solves each; the settled current must
            % equal mpcmove -> force_to_damping -> clip -> damper map. The states
            % must hit both limits, the free optimum and passive.
            P = setup_params(); mpc = design_mpc(P);
            rng(5);
            n = 20; N = 40; Hold = N*round(P.mpc.Ts/1e-3);
            X = [0.05 0.5 0.005 1 2000].*(2*rand(n, 5) - 1);
            X(n, 4) = X(n, 2);                                    % v_rel = 0
            [I_hand, cases] = mpcHand(P, mpc, X, N);
            tc.assertTrue(all(ismember({'soft limit', 'firm limit', 'between', 'passive'}, cases)), ...
                'test states must cover every case');
            % zr = 0 so zr_dot = 0; zu = x3, zs = x1 + x3 give the same states
            u = [X(:, 2), X(:, 4), zeros(n, 1), 5*ones(n, 1), X(:, 1) + X(:, 3), X(:, 3), zeros(n, 1), X(:, 5)];
            i_cmd = tc.simulateController(P, repelem(u, Hold, 1));
            I_model = i_cmd(Hold:Hold:end);
            err = max(abs(I_model - I_hand));
            tc.verifyLessThanOrEqual(err, 1e-12, sprintf('largest current difference %.3g A', err));
            record_evidence('REQ-F-06', 'TestModelBasedLaws/REQ_F_06_mpc_slot_matches_mpcmove', ...
                'largest current difference, MPC slot vs mpcmove', err, 'A');
        end

    end

    methods (Test, TestTags = {'REQ-F-07'})
        function REQ_F_07_mpc_force_within_bounds_closed_loop(tc)
            % Closed loop on C80: every MPC solve must return a force between
            % c_min*v_rel and c_max*v_rel of the same MPC sample (F_mpc and
            % v_mpc are logged signals in Law_5_MPC).
            P = setup_params();
            [t, zr] = road_iso8608('C', 80, 10, 1);
            in = Simulink.SimulationInput('harness');
            in = in.setVariable('P', P);
            in = in.setVariable('mpc_law5', design_mpc(P));
            in = in.setVariable('road_in', [t zr]);
            in = in.setVariable('fault_in', [t 0*t]);
            in = in.setVariable('mode_in', [t 5 + 0*t]);
            in = in.setModelParameter('StopTime', num2str(t(end)), 'SignalLogging', 'on', 'SignalLoggingName', 'logsout');
            out = sim(in);
            F = out.logsout.get('F_mpc').Values.Data(:);
            v = out.logsout.get('v_mpc').Values.Data(:);
            tc.assertEqual(numel(F), round(t(end)/P.mpc.Ts) + 1, 'F_mpc must be logged at the MPC rate');
            lo = min(P.c_min*v, P.c_max*v); hi = max(P.c_min*v, P.c_max*v);
            worst = max([lo - F; F - hi]);
            tc.verifyLessThanOrEqual(worst, 1e-6, sprintf('force %.3g N outside the semi-active limits', worst));
            record_evidence('REQ-F-07', 'TestModelBasedLaws/REQ_F_07_mpc_force_within_bounds_closed_loop', ...
                'largest bound violation, closed loop SC-C80 10 s', worst, 'N');
        end
    end

    methods (Test)
        function lqr_at_rest_is_passive(tc)
            % Vehicle at rest: F = -K*0 = 0, so F*v_rel = 0 is not dissipative
            % and the rule selects passive damping.
            P = setup_params();
            [I_model, ~, ~] = tc.compare(P, zeros(1, 5));
            tc.verifyEqual(I_model, P.I_passive, 'AbsTol', 1e-12);
        end

        function v1_laws_ignore_new_inputs(tc)
            % Modes 0-3 must give the same current whatever inputs 5-8 are:
            % v1 behavior unchanged by interface v2 (D36).
            P = setup_params();
            rng(22);
            for m = 0:3
                base = [0.3 -0.1 0 m];
                u0 = repmat([base 0 0 0 0], 50, 1);
                u1 = repmat([base 0.04 -0.02 0.01 900], 50, 1);
                tc.verifyEqual(tc.simulateController(P, u1), tc.simulateController(P, u0), sprintf('mode %d', m));
            end
        end
        function mpc_uses_road_velocity(tc)
            % Road rising at a = 0.2 m/s with the state unchanged: the slot must
            % match mpcmove with md = zr_dot (backward difference from 0), and
            % differ clearly from md = 0, else the md input is not connected.
            P = setup_params(); mpc = design_mpc(P);
            rng(5); X = [0.05 0.5 0.005 1 2000].*(2*rand(6, 5) - 1);
            x = X(6, :);                                          % a state between the limits
            a = 0.2; N = 40; Hold = N*round(P.mpc.Ts/1e-3);
            zr = a*(0:Hold - 1)'*1e-3;
            u = [repmat([x(2) x(4) 0 5], Hold, 1), x(1) + x(3) + zr, x(3) + zr, zr, repmat(x(5), Hold, 1)];
            i_cmd = tc.simulateController(P, u);
            with = mpcHand(P, mpc, x, N, a*((1:N)' > 1));
            without = mpcHand(P, mpc, x, N);
            tc.verifyEqual(i_cmd(end), with, 'AbsTol', 1e-12);
            tc.verifyGreaterThan(abs(i_cmd(end) - without), 0.1, 'md has no effect: not connected?');
        end

    end

    methods
        function [I_model, I_hand, cases] = compare(tc, P, X)
            % Turn states back into controller inputs (zs, zu, zr chosen so the
            % differences give the state; zu = 0 is one valid choice), run, and
            % read the settled current at the end of each held row.
            n = size(X, 1);
            zs = X(:, 1); zu = zeros(n, 1); zr = -X(:, 3);
            u = [X(:, 2), X(:, 4), zeros(n, 1), 4*ones(n, 1), zs, zu, zr, X(:, 5)];
            i_cmd = tc.simulateController(P, repelem(u, tc.Hold, 1));
            I_model = i_cmd(tc.Hold:tc.Hold:end);
            I_hand = zeros(n, 1); cases = cell(n, 1);
            for k = 1:n
                x = X(k, :)'; v = x(2) - x(4); F = -P.lqr.K*x;
                c = force_to_damping(F, v, P);
                I_hand(k) = current(P, c);
                if abs(v) < P.eps_vrel
                    cases{k} = 'tiny v_rel';
                elseif F*v > 0
                    cases{k} = 'dissipative';
                else
                    cases{k} = 'non-dissipative';
                end
            end
        end

        function i_cmd = simulateController(tc, P, u)
            % Controller alone, one input row per 1 ms sample (as the C code is driven)
            t = (0:size(u, 1) - 1)'*1e-3;
            in = Simulink.SimulationInput(tc.Model);
            in = in.setVariable('P', P);
            in = in.setVariable('mpc_law5', design_mpc(P));
            in = in.setExternalInput([t u]);
            in = in.setModelParameter('StopTime', num2str(t(end)), 'SaveOutput', 'on', ...
                'OutputSaveName', 'yout', 'SaveFormat', 'Dataset');
            out = sim(in);
            i_cmd = out.yout{1}.Values.Data(:);
        end
    end
end

function I = current(P, c)
%CURRENT Hand calculation: clip c to [c_min, c_max], then inverse damper map.
c = min(max(c, P.c_min), P.c_max);
I = P.I_min + (c - P.c_min)/(P.c_max - P.c_min)*(P.I_max - P.I_min);
end

function [I, cases] = mpcHand(P, mpc, X, N, md)
%MPCHAND Hand calculation: the same chain of N mpcmove calls per state as the block.
if nargin < 5, md = zeros(N, 1); end
n = size(X, 1); I = zeros(n, 1); cases = cell(n, 1);
xs = mpcstate(mpc); o = mpcmoveopt;
for r = 1:n
    x = X(r, :)'; v = x(2) - x(4);
    o.MVMin = min(P.c_min*v, P.c_max*v); o.MVMax = max(P.c_min*v, P.c_max*v);
    for k = 1:N
        xs.Plant = x;
        [F, info] = mpcmove(mpc, xs, [], zeros(1, 3), md(k), o);
    end
    c = force_to_damping(F, v, P, info.Iterations);
    I(r) = current(P, c);
    if abs(v) < P.eps_vrel
        cases{r} = 'passive';
    elseif abs(c - P.c_min) < 1e-9*P.c_min
        cases{r} = 'soft limit';
    elseif abs(c - P.c_max) < 1e-9*P.c_max
        cases{r} = 'firm limit';
    else
        cases{r} = 'between';
    end
end
end
