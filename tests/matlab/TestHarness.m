classdef TestHarness < matlab.unittest.TestCase
    %TESTHARNESS MiL harness model/harness/harness.slx (M3): plant + controller in closed loop.

    properties (Constant)
        Model = 'harness'
        Outputs = {'zs_ddot', 'susp_travel', 'F_tire_dyn', ...           % KPI signals
                   'zs_dot', 'zu_dot', 'fault_flag', 'mode', 'i_cmd', 'fault_active'}   % controller I/O log
    end

    methods (TestClassSetup)
        function loadModel(tc)
            load_system(tc.Model);
            tc.addTeardown(@() close_system(tc.Model, 0));
        end
    end

    methods (Test)
        function references_plant_and_controller_once(tc)
            % D24: one controller file, referenced (not copied); same for the plant
            mb = find_system(tc.Model, 'LookUnderMasks', 'all', 'BlockType', 'ModelReference');
            names = sort(get_param(mb, 'ModelName'))';
            tc.verifyEqual(names, {'controller', 'plant'});
        end

        function outputs_named_and_ordered(tc)
            out = find_system(tc.Model, 'SearchDepth', 1, 'BlockType', 'Outport');
            nums = cellfun(@(b) str2double(get_param(b, 'Port')), out);
            [~, o] = sort(nums);
            tc.verifyEqual(get_param(out(o), 'Name')', tc.Outputs);
        end

        function solver_ode4_1ms(tc)
            % D8: whole harness fixed-step ode4, 1 ms
            tc.verifyEqual(get_param(tc.Model, 'SolverType'), 'Fixed-step');
            tc.verifyEqual(get_param(tc.Model, 'Solver'), 'ode4');
            tc.verifyEqual(str2double(get_param(tc.Model, 'FixedStep')), 1e-3);
        end

        function passive_closed_loop_matches_M2_baseline(tc)
            % Closed loop in mode 0 must reproduce the trusted plant-only baseline (C80)
            P = setup_params();
            [t, zr] = road_iso8608('C', 80, 30, 1);
            Y = tc.simulate(P, t, zr, 0*t, 0);
            K = kpi(Y.t, Y.zs_ddot, Y.F_tire_dyn, Y.susp_travel, P.F_static);
            B = readtable(fullfile(matlab.project.rootProject().RootFolder, 'results', 'baseline', ...
                'kpi_baseline_sedan_ref.csv'), 'TextType', 'char');
            b = B(strcmp(B.scenario, 'C80'), :);
            tc.verifyEqual(K.rms_zs_ddot, b.rms_zs_ddot, 'RelTol', 0.01, 'RMS body acceleration vs baseline');
            tc.verifyEqual(K.rms_F_tire_dyn, b.rms_F_tire_dyn, 'RelTol', 0.01, 'RMS dynamic tire load vs baseline');
            tc.verifyEqual(K.max_travel_mm, b.max_travel_mm, 'RelTol', 0.01, 'Max travel vs baseline');
        end

        function mode_set_by_parameter(tc)
            % The same model runs any mode; mode_sel reaches the controller unchanged
            P = setup_params();
            t = (0:1e-3:0.2)';
            for m = [0 1 2 3]
                Y = tc.simulate(P, t, 0*t, 0*t, m);
                tc.verifyEqual(unique(Y.mode)', m, sprintf('mode_sel = %d must reach the controller', m));
            end
        end

        function controller_io_logged_every_ms_from_t0(tc)
            % M5 answer key: one row per controller step, starting at k = 0 (mil_to_sil.md 2.3, 2.4)
            P = setup_params();
            t = (0:1e-3:1)';
            Y = tc.simulate(P, t, 0*t, 0*t, 0);
            tc.verifyEqual(Y.t, t, 'AbsTol', 1e-12, 'One logged sample per 1 ms, starting at 0');
            tc.verifyEqual(Y.i_cmd(1), P.I_default, 'Logged i_cmd(0) must be I_default (REQ-F-03)');
            tc.verifyEqual(Y.fault_active(1), 0);
        end

        function closed_loop_matches_independent_reference(tc)
            % Harness timing must equal the textbook timing (D8, D19) re-implemented in
            % plain MATLAB. Catches artificial-algebraic-loop handling (D26).
            P = setup_params();
            [t, zr] = road_iso8608('C', 80, 10, 1);
            for m = [0 1]
                Y = tc.simulate(P, t, zr, 0*t, m);
                R = reference_closed_loop(P, t, zr, m);
                tc.verifyEqual(Y.zs_dot, R.zs_dot, 'AbsTol', 1e-9, sprintf('mode %d: zs_dot vs reference', m));
                tc.verifyEqual(Y.i_cmd, R.i_cmd, 'AbsTol', 1e-9, sprintf('mode %d: i_cmd vs reference', m));
            end
        end

        function no_algebraic_loop(tc)
            % D19 delays + D26 setting: the plant-controller loop must not be algebraic
            P = setup_params();
            t = (0:1e-3:0.1)';
            lastwarn('');
            tc.simulate(P, t, 0*t, 0*t, 1);
            [~, id] = lastwarn();
            tc.verifyNotEqual(id, 'Simulink:Engine:WarnAlgLoopsFound', 'Harness contains an algebraic loop');
        end

        function fault_flag_not_smoothed(tc)
            % A one-sample fault pulse must arrive as exactly one sample of 1.0 (no interpolation)
            P = setup_params();
            t = (0:1e-3:1)';
            f = zeros(size(t)); f(501) = 1;              % pulse at t = 0.5 s
            Y = tc.simulate(P, t, 0*t, f, 0);
            tc.verifyTrue(all(Y.fault_flag == 0 | Y.fault_flag == 1), 'fault_flag must only be 0 or 1');
            tc.verifyEqual(nnz(Y.fault_flag), 1, 'Exactly one fault sample');
            tc.verifyEqual(Y.t(Y.fault_flag == 1), 0.5, 'AbsTol', 1e-9, 'Pulse at the commanded time');
        end
    end

    methods
        function Y = simulate(tc, P, t, zr, fault, mode_sel)
            in = Simulink.SimulationInput(tc.Model);
            in = in.setVariable('P', P);
            in = in.setVariable('road_in', [t zr]);
            in = in.setVariable('fault_in', [t fault]);
            in = in.setVariable('mode_sel', mode_sel);
            in = in.setModelParameter('StopTime', num2str(t(end)), 'SaveOutput', 'on', ...
                'OutputSaveName', 'yout', 'SaveFormat', 'Dataset');
            out = sim(in);
            Y.t = out.yout{1}.Values.Time;
            for k = 1:numel(tc.Outputs)
                Y.(tc.Outputs{k}) = out.yout{k}.Values.Data(:);
            end
        end
    end
end
