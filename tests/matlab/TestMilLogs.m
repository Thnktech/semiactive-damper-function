classdef TestMilLogs < matlab.unittest.TestCase
    %TESTMILLOGS MiL reference logs in tests/data (M3 -> M5 answer key).
    %   1) Replaying the logged inputs into the controller alone must reproduce
    %      the logged outputs bit for bit (what M5 will require of the C code).
    %   2) Together, the logs must cover every function the C code has.

    properties (TestParameter)
        scenario = {'SC-C80', 'SC-BUMP', 'SC-FAULT'}
    end

    methods (TestClassSetup)
        function loadModel(tc)
            load_system('controller');
            tc.addTeardown(@() close_system('controller', 0));
        end
    end

    methods (Test)
        function replay_reproduces_log_exactly(tc, scenario)
            L = tc.readLog(scenario);
            P = setup_params();
            in = Simulink.SimulationInput('controller');
            in = in.setVariable('P', P);
            in = in.setExternalInput([L.t, L.zs_dot, L.zu_dot, L.fault_flag, L.mode]);
            in = in.setModelParameter('StopTime', num2str(L.t(end)), 'SaveOutput', 'on', ...
                'OutputSaveName', 'yout', 'SaveFormat', 'Dataset');
            out = sim(in);
            tc.verifyEqual(out.yout{1}.Values.Data(:), L.i_cmd, sprintf('%s: i_cmd replay', scenario));
            tc.verifyEqual(out.yout{2}.Values.Data(:), L.fault_active, sprintf('%s: fault_active replay', scenario));
        end

        function log_follows_rules(tc, scenario)
            % mil_to_sil.md 2.3-2.6: one row per 1 ms from t = 0, step 0 = initial outputs
            L = tc.readLog(scenario);
            P = setup_params();
            tc.verifyEqual(L.t(1), 0);
            tc.verifyEqual(diff(L.t), 1e-3*ones(height(L) - 1, 1), 'AbsTol', 1e-9);
            tc.verifyEqual(L.i_cmd(1), P.I_default);
            tc.verifyEqual(L.fault_active(1), 0);
        end

        function logs_cover_all_functions(tc)
            % mil_to_sil.md section 4: the replay only proves what the logs contain
            P = setup_params();
            A = vertcat(tc.readLog('SC-C80'), tc.readLog('SC-BUMP'), tc.readLog('SC-FAULT'));
            for m = 0:3
                tc.verifyTrue(any(A.mode == m), sprintf('mode %d not exercised', m));
            end
            tc.verifyTrue(any(A.mode == 7) && any(A.mode == 1.5), 'invalid modes not exercised');
            tc.verifyTrue(any(abs(A.i_cmd - P.I_max) < 1e-12), 'upper current limit not reached');
            tc.verifyTrue(any(abs(A.i_cmd - P.I_min) < 1e-12), 'lower current limit not reached');
            tc.verifyTrue(any(abs(abs(diff(A.i_cmd)) - P.dI_max) < 1e-12), 'rate limit not active');
            v = A.zs_dot - A.zu_dot;
            tc.verifyTrue(any(diff(sign(v)) ~= 0), 'v_rel never crosses zero');
            F = tc.readLog('SC-FAULT');
            tc.verifyEqual(nnz(diff(F.fault_active) > 0), 1, 'fault latch: exactly one 0 -> 1');
            tc.verifyTrue(nnz(diff(F.fault_flag) ~= 0) > 4, 'fault flag toggling not exercised');
        end
    end

    methods
        function L = readLog(tc, scenario)
            f = fullfile(matlab.project.rootProject().RootFolder, 'tests', 'data', ['mil_' scenario '.csv']);
            tc.assumeTrue(isfile(f), sprintf('%s missing: run log_mil_reference', f));
            L = readtable(f);
        end
    end
end
