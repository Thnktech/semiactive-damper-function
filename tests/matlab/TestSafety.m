classdef TestSafety < matlab.unittest.TestCase
    %TESTSAFETY Safety_and_limits of controller.slx: REQ-F-01, REQ-F-04, REQ-S-01, REQ-S-02.
    %   The controller is driven alone from MATLAB with input sequences.

    properties (Constant)
        Model = 'controller'
        % Room for round-off only, as in the REQ-F-04 acceptance (+1e-12 A).
        Tol = 1e-12
    end

    methods (TestClassSetup)
        function loadModel(tc)
            load_system(tc.Model);
            tc.addTeardown(@() close_system(tc.Model, 0));
        end
    end

    methods (Test, TestTags = {'REQ-F-01'})
        function REQ_F_01_current_within_limits(tc)
            % Extreme velocities, random mode switching (incl. invalid modes), faults
            P = setup_params();
            % Fixed seed: the random input sequence is the same in every run, so a
            % failure can be reproduced.
            rng(11);
            n = 3001;
            zs = 10*(2*rand(n, 1) - 1);  zu = 10*(2*rand(n, 1) - 1);
            mode = repelem(randi([-1 5], ceil(n/100), 1), 100); mode = mode(1:n);
            fault = double((1:n)' > 2500);
            Y = tc.runController(P, [zs zu fault mode]);
            tc.verifyGreaterThanOrEqual(min(Y.i_cmd), P.I_min - tc.Tol, sprintf('min i_cmd = %.6f A', min(Y.i_cmd)));
            tc.verifyLessThanOrEqual(max(Y.i_cmd), P.I_max + tc.Tol, sprintf('max i_cmd = %.6f A', max(Y.i_cmd)));
            record_evidence('REQ-F-01', 'TestSafety/REQ_F_01_current_within_limits', 'min i_cmd', min(Y.i_cmd), 'A');
            record_evidence('REQ-F-01', 'TestSafety/REQ_F_01_current_within_limits', 'max i_cmd', max(Y.i_cmd), 'A');
        end
    end

    methods (Test, TestTags = {'REQ-F-04'})
        function REQ_F_04_rate_never_exceeded(tc)
            % Alternate soft/firm requests every step: the limiter must cap every change
            P = setup_params();
            n = 2001;
            zs = 0.2*ones(n, 1);
            zu = 0.1 + 0.2*mod((0:n-1)', 2);          % v_rel alternates +0.1 / -0.1 -> 1.6 A / 0.3 A
            Y = tc.runController(P, [zs zu zeros(n, 1) ones(n, 1)]);
            d = max(abs(diff(Y.i_cmd)));
            tc.verifyLessThanOrEqual(d, P.dI_max + tc.Tol, sprintf('max |delta i_cmd| = %.6f A per step', d));
            record_evidence('REQ-F-04', 'TestSafety/REQ_F_04_rate_never_exceeded', 'max |delta i_cmd| per step', d, 'A');
        end

        function REQ_F_04_rate_limit_is_active(tc)
            % From I_default 0.95 A to a 1.6 A request: exactly 0.13 A per step, 5 steps
            P = setup_params();
            n = 21;
            Y = tc.runController(P, repmat([0.2 0.1 0 1], n, 1));   % skyhook -> c_max -> 1.6 A
            expected = min(P.I_default + (0:n-1)'*P.dI_max, P.I_max);
            tc.verifyEqual(Y.i_cmd, expected, 'AbsTol', tc.Tol);
        end
    end

    methods (Test, TestTags = {'REQ-S-01'})
        function REQ_S_01_fault_reaction_time(tc)
            % At 1.6 A, fault at k0: from the first fault sample to |i_cmd - I_default| <= 1e-3
            % and staying there must take <= 10 ms (REQ.md: t_react, tol_I)
            P = setup_params();
            n = 200; k0 = 101;
            u = repmat([0.2 0.1 0 1], n, 1); u(k0:end, 3) = 1;
            Y = tc.runController(P, u);
            tc.assertEqual(Y.i_cmd(k0), P.I_max, 'AbsTol', tc.Tol, 'Precondition: at I_max before the fault');
            ok = abs(Y.i_cmd - P.I_default) <= 1e-3;
            ks = find(~ok, 1, 'last') + 1;            % first sample from which it stays settled
            t_react = (ks - k0)*1e-3;
            tc.verifyLessThanOrEqual(t_react, 0.010, sprintf('Fault reaction %.1f ms > 10 ms', 1e3*t_react));
            % 0.65 A at 0.13 A per step = 5 steps; the output delay is the first of them
            tc.verifyEqual(t_react, 0.005, 'AbsTol', 1e-9, sprintf('Expected 5 ms (5 rate-limited steps), got %.1f ms', 1e3*t_react));
            record_evidence('REQ-S-01', 'TestSafety/REQ_S_01_fault_reaction_time', 'fault reaction time', 1e3*t_react, 'ms');
        end

        % Under a fault every mode, also an invalid one (7), must end at I_default: the
        % fault path must act after the law selection, not inside one law.
        function REQ_S_01_fault_overrides_every_mode(tc)
            P = setup_params();
            for m = [0 1 2 3 7]
                u = repmat([0.2 0.1 1 m], 60, 1);
                Y = tc.runController(P, u);
                tc.verifyEqual(Y.i_cmd(end), P.I_default, 'AbsTol', tc.Tol, sprintf('mode %d under fault', m));
            end
        end
    end

    methods (Test, TestTags = {'REQ-S-02'})
        % One sample of fault_flag is enough: the fault latches for the rest of the run
        % (no reset input, D18) and i_cmd stays at I_default.
        function REQ_S_02_single_pulse_latches(tc)
            P = setup_params();
            n = 300; u = repmat([0.2 0.1 0 1], n, 1); u(101, 3) = 1;   % one-sample pulse
            Y = tc.runController(P, u);
            tc.verifyEqual(nnz(diff(Y.fault_active) > 0), 1, 'Exactly one 0 -> 1 transition');
            tc.verifyEqual(nnz(diff(Y.fault_active) < 0), 0, 'No 1 -> 0 transition');
            tc.verifyEqual(Y.fault_active(end), 1);
            tc.verifyEqual(Y.i_cmd(150:end), P.I_default*ones(n - 149, 1), 'AbsTol', 1e-3, ...
                'i_cmd must stay at I_default after the pulse');
            record_evidence('REQ-S-02', 'TestSafety/REQ_S_02_single_pulse_latches', '1 -> 0 transitions after a pulse', nnz(diff(Y.fault_active) < 0), 'count');
        end

        % A flickering flag (on/off every 100 ms) must never clear the latch.
        function REQ_S_02_toggling_flag_cannot_clear(tc)
            P = setup_params();
            n = 1001; u = repmat([0.2 0.1 0 1], n, 1);
            k = (0:n-1)'; u(:, 3) = double(k >= 200 & mod(floor(k/100), 2) == 0);  % toggles every 100 ms
            Y = tc.runController(P, u);
            tc.verifyEqual(nnz(diff(Y.fault_active) > 0), 1, 'Exactly one 0 -> 1 transition');
            tc.verifyEqual(nnz(diff(Y.fault_active) < 0), 0, 'No 1 -> 0 transition while toggling');
            record_evidence('REQ-S-02', 'TestSafety/REQ_S_02_toggling_flag_cannot_clear', '1 -> 0 transitions while toggling', nnz(diff(Y.fault_active) < 0), 'count');
        end
    end

    methods (Test, TestTags = {'REQ-F-03'})
        function fault_at_step_0_is_registered(tc)
            % D19: outputs are delayed, so step 0 still shows the initial values
            P = setup_params();
            Y = tc.runController(P, repmat([0 0 1 0], 5, 1));
            tc.verifyEqual(Y.fault_active(1:2)', [0 1]);
            tc.verifyEqual(Y.i_cmd(1), P.I_default);
        end
    end

    methods
        % Helper: controller alone, one input row per 1 ms sample.
        function Y = runController(tc, P, u)
            t = (0:size(u, 1) - 1)'*1e-3;
            in = Simulink.SimulationInput(tc.Model);
            in = in.setVariable('P', P);
            in = in.setExternalInput([t u]);
            in = in.setModelParameter('StopTime', num2str(t(end)), 'SaveOutput', 'on', ...
                'OutputSaveName', 'yout', 'SaveFormat', 'Dataset');
            out = sim(in);
            Y.i_cmd = out.yout{1}.Values.Data(:);
            Y.fault_active = out.yout{2}.Values.Data(:);
        end
    end
end
