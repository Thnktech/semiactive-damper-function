classdef TestComparison < matlab.unittest.TestCase
    %TESTCOMPARISON Committed controller comparison (M3, run_comparison.m).
    %   Checks the committed results file instead of re-running 36 simulations (~2 min).

    properties (Constant)
        Scenarios = {'A50', 'A80', 'B50', 'B80', 'C50', 'C80', 'D50', 'D80', 'BUMP'}
        Modes = {'passive', 'skyhook', 'groundhook', 'hybrid'}
    end

    methods (Test)
        % The committed CSV must be complete: 9 scenarios x 4 modes, one row each, and
        % mode names that match the mode numbers.
        function every_scenario_in_every_mode(tc)
            T = tc.readComparison();
            tc.verifyEqual(height(T), numel(tc.Scenarios)*numel(tc.Modes));
            for s = tc.Scenarios
                for m = 0:3
                    r = strcmp(T.scenario, s{1}) & T.mode == m;
                    tc.verifyEqual(nnz(r), 1, sprintf('%s, mode %d: exactly one row', s{1}, m));
                    if nnz(r) == 1
                        tc.verifyEqual(T.mode_name{r}, tc.Modes{m+1});
                    end
                end
            end
        end

        function passive_rows_equal_M2_baseline(tc)
            % Proves identical inputs: closed loop in mode 0 reproduces the plant-only baseline
            T = tc.readComparison();
            B = readtable(fullfile(tc.root(), 'results', 'baseline', 'kpi_baseline_sedan_ref.csv'), 'TextType', 'char');
            for s = tc.Scenarios
                r = strcmp(T.scenario, s{1}) & T.mode == 0;
                b = strcmp(B.scenario, s{1});
                for k = {'rms_zs_ddot', 'rms_F_tire_dyn', 'max_travel_mm'}
                    tc.verifyEqual(T.(k{1})(r), B.(k{1})(b), 'RelTol', 1e-6, sprintf('%s %s', s{1}, k{1}));
                end
            end
        end

        % The % columns are what the reports quote: recompute them from the absolute
        % KPIs, and passive vs itself must be exactly 0.
        function deltas_recomputed_independently(tc)
            T = tc.readComparison();
            for r = 1:height(T)
                p = strcmp(T.scenario, T.scenario{r}) & T.mode == 0;
                tc.verifyEqual(T.d_comfort_pct(r), 100*(T.rms_zs_ddot(r)/T.rms_zs_ddot(p) - 1), 'AbsTol', 1e-9);
                tc.verifyEqual(T.d_tire_pct(r), 100*(T.rms_F_tire_dyn(r)/T.rms_F_tire_dyn(p) - 1), 'AbsTol', 1e-9);
                tc.verifyEqual(T.d_travel_pct(r), 100*(T.max_travel_mm(r)/T.max_travel_mm(p) - 1), 'AbsTol', 1e-9);
            end
            tc.verifyEqual(T.d_comfort_pct(T.mode == 0), zeros(nnz(T.mode == 0), 1), 'Passive deltas must be 0');
        end

        function result_files_carry_vehicle_name(tc)
            d = dir(fullfile(tc.root(), 'results', 'comparison', '*.*'));
            d = d(~[d.isdir]);
            tc.assumeNotEmpty(d, 'No comparison results yet');
            for k = 1:numel(d)
                tc.verifySubstring(d(k).name, '_sedan_ref', sprintf('%s must contain the vehicle (D13, D21)', d(k).name));
            end
        end

        function no_hard_coded_paths_in_sources(tc)
            % Scripts must work in any clone: use project_root(), never an absolute path.
            % Note: the check also hits text such as 'failed:' followed by a newline
            % escape (letter, colon, backslash); reword such messages.
            f = dir(fullfile(tc.root(), 'src', 'matlab', '**', '*.m'));
            for k = 1:numel(f)
                if contains(f(k).folder, [filesep 'private']), continue; end
                txt = fileread(fullfile(f(k).folder, f(k).name));
                tc.verifyEmpty(regexp(txt, '[A-Za-z]:\\', 'once'), sprintf('%s contains an absolute Windows path', f(k).name));
            end
        end
    end

    methods
        function r = root(~)
            r = matlab.project.rootProject().RootFolder;
        end

        % Read the committed file instead of re-running 36 simulations (~2 min).
        function T = readComparison(tc)
            f = fullfile(tc.root(), 'results', 'comparison', 'kpi_comparison_sedan_ref.csv');
            tc.assumeTrue(isfile(f), 'Run run_comparison() first');
            T = readtable(f, 'TextType', 'char');
        end
    end
end
