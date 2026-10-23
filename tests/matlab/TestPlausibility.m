classdef (TestTags = {'Plausibility'}) TestPlausibility < matlab.unittest.TestCase
    %TESTPLAUSIBILITY Physical sanity and regression checks of the MiL closed loop (M4).
    %   Not tied to a single requirement: they catch modelling errors that would
    %   make every requirement verdict meaningless.

    properties (Constant)
        Modes = [0 1 2 3]
    end

    methods (TestClassSetup)
        function loadModels(tc)
            load_system('harness'); load_system('plant');
            tc.addTeardown(@() close_system('harness', 0));
            tc.addTeardown(@() close_system('plant', 0));
        end
    end

    methods (Test)
        function zero_road_zero_motion_every_mode(tc)
            % Flat road: the car must stay at rest whatever the strategy commands
            P = setup_params();
            t = (0:1e-3:3)';
            for m = tc.Modes
                Y = simulate_harness(P, t, 0*t, m);
                for f = {'zs_dot', 'zu_dot', 'zs_ddot', 'susp_travel', 'F_tire_dyn'}
                    tc.verifyLessThan(max(abs(Y.(f{1}))), 1e-9, sprintf('mode %d: %s moves on a flat road', m, f{1}));
                end
                late = Y.t > 2;
                tc.verifyEqual(max(Y.i_cmd(late)) - min(Y.i_cmd(late)), 0, 'AbsTol', 1e-12, sprintf('mode %d: current not settled at rest', m));
            end
        end

        function damper_only_dissipates(tc)
            % Semi-active: the damper can only take energy out. Power absorbed
            % P_d = F_d * (zu_dot - zs_dot) = c * v^2 >= 0 at every sample, and the
            % effective damping stays within [c_min, c_max]. Read from the plant's
            % internal damper force while the plant is driven by a skyhook current.
            P = setup_params();
            [t, zr] = road_iso8608('C', 80, 10, 1);
            Ys = simulate_harness(P, t, zr, 1);                       % skyhook current sequence
            fd = 'plant/QC_Model_Blocks/Product';                     % damper force c * (zu_dot - zs_dot)
            dv = 'plant/QC_Model_Blocks/Add1';                        % zu_dot - zs_dot
            tc.assertTrue(getSimulinkBlockHandle(fd) > 0 && getSimulinkBlockHandle(dv) > 0, ...
                'Damper force / velocity blocks not found in plant.slx (renamed?)');
            ph1 = get_param(fd, 'PortHandles'); ph2 = get_param(dv, 'PortHandles');
            set_param(ph1.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'F_d');
            set_param(ph2.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'dv');
            in = Simulink.SimulationInput('plant');
            in = in.setVariable('P', P);
            in = in.setExternalInput([t zr Ys.i_cmd]);
            in = in.setBlockParameter('plant/i_cmd', 'Interpolate', 'off');   % held like a 1 ms controller output
            in = in.setModelParameter('StopTime', num2str(t(end)), 'SignalLogging', 'on', 'SignalLoggingName', 'logsout');
            out = sim(in);
            F = out.logsout.get('F_d').Values.Data(:);
            V = out.logsout.get('dv').Values.Data(:);
            Pd = F.*V;
            tc.verifyGreaterThanOrEqual(min(Pd), -1e-9, sprintf('Damper adds energy: min power %.3g W', min(Pd)));
            big = abs(V) > 1e-4;
            c = F(big)./V(big);
            tc.verifyGreaterThanOrEqual(min(c), P.c_min*(1 - 1e-9), sprintf('Damping %.1f below c_min', min(c)));
            tc.verifyLessThanOrEqual(max(c), P.c_max*(1 + 1e-9), sprintf('Damping %.1f above c_max', max(c)));
        end

        function regression_C80_all_modes_vs_committed(tc)
            % Any model change that moves the committed comparison results is caught here
            f = fullfile(matlab.project.rootProject().RootFolder, 'results', 'comparison', 'kpi_comparison_sedan_ref.csv');
            tc.assumeTrue(isfile(f), 'Run run_comparison() first');
            C = readtable(f, 'TextType', 'char');
            P = setup_params();
            [t, zr] = road_iso8608('C', 80, 30, 1);
            for m = tc.Modes
                Y = simulate_harness(P, t, zr, m);
                K = kpi(Y.t, Y.zs_ddot, Y.F_tire_dyn, Y.susp_travel, P.F_static);
                r = strcmp(C.scenario, 'C80') & C.mode == m;
                for k = {'rms_zs_ddot', 'rms_F_tire_dyn', 'max_travel_mm'}
                    tc.verifyEqual(K.(k{1}), C.(k{1})(r), 'RelTol', 1e-6, sprintf('mode %d: %s moved vs committed results', m, k{1}));
                end
            end
        end
    end
end
