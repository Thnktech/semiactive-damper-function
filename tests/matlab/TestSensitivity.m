classdef TestSensitivity < matlab.unittest.TestCase
    %TESTSENSITIVITY Committed actuator-lag sensitivity study (M6, run_lag_sensitivity.m).
    %   Checks the committed results file instead of re-running 12 simulations
    %   (~1 min). The README quotes these numbers, so they must be complete and
    %   consistent with the rest of the project.

    properties (Constant)
        Taus = [5 10 20]                                     % ms
        Modes = {'passive', 'skyhook', 'groundhook', 'hybrid'}
    end

    methods (Test)
        % Complete: 3 lags x 4 modes, one row each, mode names matching numbers.
        function every_lag_in_every_mode(tc)
            T = tc.readStudy();
            tc.verifyEqual(height(T), numel(tc.Taus)*numel(tc.Modes));
            for tau = tc.Taus
                for m = 0:3
                    r = T.tau_ms == tau & T.mode == m;
                    tc.verifyEqual(nnz(r), 1, sprintf('tau %d ms, mode %d: exactly one row', tau, m));
                    if nnz(r) == 1
                        tc.verifyEqual(T.mode_name{r}, tc.Modes{m+1});
                    end
                end
            end
        end

        % tau = 10 ms is the project default: the same run as the M3 comparison
        % on C80, so the numbers must be equal. Proves the study changed nothing
        % but the lag.
        function default_lag_equals_M3_comparison(tc)
            T = tc.readStudy();
            C = readtable(fullfile(project_root(), 'results', 'comparison', ...
                'kpi_comparison_sedan_ref.csv'), 'TextType', 'char');
            for m = 0:3
                s = T(T.tau_ms == 10 & T.mode == m, :);
                c = C(strcmp(C.scenario, 'C80') & C.mode == m, :);
                for k = {'rms_zs_ddot', 'rms_F_tire_dyn', 'max_travel_mm'}
                    tc.verifyEqual(s.(k{1}), c.(k{1}), 'RelTol', 1e-9, ...
                        sprintf('mode %d, %s: tau = 10 ms differs from the M3 comparison', m, k{1}));
                end
            end
        end

        % Passive uses one constant current, so the valve lag cannot matter
        % after the start-up (KPIs start at 2 s). If passive changed with tau,
        % the lag would act somewhere it should not.
        function passive_does_not_depend_on_lag(tc)
            T = tc.readStudy();
            p = T(T.mode == 0, :);
            for k = {'rms_zs_ddot', 'rms_F_tire_dyn', 'max_travel_mm'}
                v = p.(k{1});
                tc.verifyEqual(v, v(1)*ones(size(v)), 'RelTol', 1e-6, ...
                    sprintf('passive %s changes with tau', k{1}));
            end
        end

        % The % columns are what the README quotes: recompute them from the
        % absolute KPIs (vs passive at the same lag).
        function deltas_recomputed_independently(tc)
            T = tc.readStudy();
            for r = 1:height(T)
                p = T.tau_ms == T.tau_ms(r) & T.mode == 0;
                tc.verifyEqual(T.d_comfort_pct(r), 100*(T.rms_zs_ddot(r)/T.rms_zs_ddot(p) - 1), 'AbsTol', 1e-9);
                tc.verifyEqual(T.d_tire_pct(r), 100*(T.rms_F_tire_dyn(r)/T.rms_F_tire_dyn(p) - 1), 'AbsTol', 1e-9);
                tc.verifyEqual(T.d_travel_pct(r), 100*(T.max_travel_mm(r)/T.max_travel_mm(p) - 1), 'AbsTol', 1e-9);
            end
        end

        % Vehicle name in the file names (D13, D21), as for all results.
        function result_files_carry_vehicle_name(tc)
            d = dir(fullfile(project_root(), 'results', 'sensitivity', '*.*'));
            d = d(~[d.isdir]);
            tc.assumeNotEmpty(d, 'No sensitivity results yet');
            for k = 1:numel(d)
                tc.verifySubstring(d(k).name, '_sedan_ref', sprintf('%s must contain the vehicle', d(k).name));
            end
        end
    end

    methods
        % Read the committed file; 'assume' skips (instead of failing) before
        % run_lag_sensitivity() has been run once.
        function T = readStudy(tc)
            f = fullfile(project_root(), 'results', 'sensitivity', 'lag_sensitivity_sedan_ref.csv');
            tc.assumeTrue(isfile(f), 'Run run_lag_sensitivity() first');
            T = readtable(f, 'TextType', 'char');
        end
    end
end
